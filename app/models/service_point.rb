class ServicePoint < ApplicationRecord
  # Связи
  belongs_to :partner
  belongs_to :city
  belongs_to :status, class_name: 'ServicePointStatus', foreign_key: 'status_id'
  has_many :photos, class_name: 'ServicePointPhoto', dependent: :destroy
  has_many :service_point_amenities, dependent: :destroy
  has_many :amenities, through: :service_point_amenities
  has_many :manager_service_points, dependent: :destroy
  has_many :managers, through: :manager_service_points
  has_many :schedule_templates, dependent: :destroy
  has_many :schedule_exceptions, dependent: :destroy
  has_many :schedule_slots, dependent: :destroy
  has_many :bookings, dependent: :restrict_with_error
  has_many :reviews, dependent: :destroy
  has_many :price_lists, dependent: :destroy
  has_many :promotions, dependent: :destroy
  has_many :client_favorite_points, dependent: :destroy
  has_many :favorited_by_clients, through: :client_favorite_points, source: :client
  
  # Добавляем связь с услугами
  has_many :service_point_services, dependent: :destroy
  has_many :services, through: :service_point_services
  
  # Добавляем связь с постами обслуживания
  has_many :service_posts, dependent: :destroy
  
  # Принимаем вложенные атрибуты
  accepts_nested_attributes_for :photos, allow_destroy: true
  accepts_nested_attributes_for :service_point_services, allow_destroy: true
  
  # Валидации
  # Удаляем валидацию уникальности имени, чтобы разрешить одинаковые имена у разных партнеров/городов
  validates :name, presence: true
  validates :address, presence: true
  validates :post_count, numericality: { greater_than: 0 }
  validates :default_slot_duration, numericality: { greater_than: 0 }
  
  # Геолокация
  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true
  
  # Скоупы
  scope :active, -> { joins(:status).where(service_point_statuses: { name: 'active' }) }
  scope :by_city, ->(city_id) { where(city_id: city_id) }
  scope :by_partner, ->(partner_id) { where(partner_id: partner_id) }
  scope :with_amenities, ->(amenity_ids) { 
    return none if amenity_ids.blank?
    
    # Convert to array if it's not already
    amenity_ids = Array(amenity_ids)
    
    # Group service points by their ID and count how many of the specified amenities they have
    joins(:service_point_amenities)
      .where(service_point_amenities: { amenity_id: amenity_ids })
      .group(:id)
      .having("COUNT(DISTINCT service_point_amenities.amenity_id) = ?", amenity_ids.length)
  }
  scope :near, ->(latitude, longitude, distance_km = 10) {
    # Примечание: это очень упрощенный расчет, в реальном проекте используйте PostGIS или геопространственные функции
    where("
      (6371 * acos(cos(radians(?)) * cos(radians(latitude)) * cos(radians(longitude) - radians(?)) + sin(radians(?)) * sin(radians(latitude)))) < ?",
      latitude, longitude, latitude, distance_km)
  }
  
  # Методы
  def active?
    status.name == 'active'
  end
  
  # Количество активных постов обслуживания
  def posts_count
    service_posts.active.count
  end
  
  def temporarily_closed?
    status.name == 'temporarily_closed'
  end
  
  def closed?
    status.name == 'closed'
  end
  
  def maintenance?
    status.name == 'maintenance'
  end
  
  def recalculate_metrics!
    update(
      total_clients_served: bookings.joins(:status).where(booking_statuses: { name: 'completed' }).count,
      average_rating: reviews.average(:rating) || 0.0,
      cancellation_rate: calculate_cancellation_rate
    )
  end
  
  # Новые методы для работы с расписанием
  
  # Генерирует слоты расписания на указанную дату
  def generate_schedule_for_date(date)
    ScheduleManager.generate_slots_for_date(id, date)
  end
  
  # Генерирует слоты расписания на указанный период
  def generate_schedule_for_period(start_date, end_date)
    ScheduleManager.generate_slots_for_period(id, start_date, end_date)
  end
  
  # Получает доступные слоты расписания на указанную дату
  def available_slots_for_date(date)
    schedule_slots.where(slot_date: date, is_available: true)
                  .left_joins(:bookings)
                  .where(bookings: { id: nil })
                  .order(start_time: :asc)
  end
  
  # Находит ближайший свободный слот для бронирования
  def find_next_available_slot(date = Date.current, preferred_time = nil)
    ScheduleManager.find_next_available_slot(id, date, preferred_time)
  end
  
  # Проверяет, доступно ли указанное время для бронирования
  def is_time_available?(date, start_time, end_time)
    ScheduleManager.is_time_available?(id, date, start_time, end_time)
  end
  
  # Получает загруженность на указанную дату (процент занятых слотов)
  def occupancy_for_date(date)
    total_slots = schedule_slots.where(slot_date: date).count
    return 0 if total_slots.zero?
    
    booked_slots = schedule_slots.where(slot_date: date)
                                 .joins(:bookings)
                                 .where.not(bookings: { id: nil })
                                 .count
    
    (booked_slots.to_f / total_slots) * 100
  end
  
  # Получает рейтинг загруженности по дням недели (среднее значение за последние 4 недели)
  def weekly_occupancy
    result = {}
    
    # Получаем даты последних 4 недель
    end_date = Date.current
    start_date = end_date - 4.weeks
    
    # Группируем слоты по дню недели и вычисляем средний процент занятости
    (start_date..end_date).group_by(&:wday).each do |wday, dates|
      occupancy_sum = dates.sum { |date| occupancy_for_date(date) }
      result[wday] = (occupancy_sum / dates.count).round(2)
    end
    
    result
  end
  
  # Получает идентификаторы услуг, доступных в этой точке
  def available_service_ids
    service_point_services.pluck(:service_id)
  end
  
  # Проверяет, доступна ли указанная услуга в этой точке
  def service_available?(service_id)
    service_point_services.exists?(service_id: service_id)
  end
  
  # Получает цену указанной услуги в этой точке
  def price_for_service(service_id)
    service = Service.find(service_id)
    service.current_price_for_service_point(id) || service.base_price
  end
  
  # Добавляет услугу в список доступных в этой точке
  def add_service(service_id)
    return if service_available?(service_id)
    
    service_point_services.create(service_id: service_id)
  end
  
  # Удаляет услугу из списка доступных в этой точке
  def remove_service(service_id)
    service_point_services.find_by(service_id: service_id)&.destroy
  end
  
  private
  
  def calculate_cancellation_rate
    total = bookings.count
    return 0.0 if total.zero?
    
    cancelled = bookings.joins(:status).where(booking_statuses: { name: ['canceled_by_client', 'canceled_by_partner', 'no_show'] }).count
    (cancelled.to_f / total) * 100
  end
end
