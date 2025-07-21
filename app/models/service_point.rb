class ServicePoint < ApplicationRecord
  # Связи
  belongs_to :partner
  belongs_to :city
  # Убираем связь со старой таблицей статусов - теперь используем is_active и work_status
  has_many :photos, class_name: 'ServicePointPhoto', dependent: :destroy
  has_many :service_point_amenities, dependent: :destroy
  has_many :amenities, through: :service_point_amenities
  has_many :manager_service_points, dependent: :destroy
  has_many :managers, through: :manager_service_points
  has_many :schedule_templates, dependent: :destroy
  has_many :schedule_exceptions, dependent: :destroy
  has_many :schedule_slots, dependent: :destroy
  has_many :seasonal_schedules, dependent: :destroy
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
  accepts_nested_attributes_for :service_posts, allow_destroy: true
  
  # Callback для перенумерации постов после сохранения
  after_save :renumber_service_posts
  
  # Callback для анализа конфликтов при изменении статуса
  after_update :analyze_booking_conflicts_if_status_changed
  
  # Колбэки для уведомлений администраторов
  after_create :send_service_point_creation_notification, unless: -> { skip_notifications }
  after_update :send_service_point_change_notification, if: -> { significant_changes? && !skip_notifications }
  after_update :send_service_point_status_change_notification, if: -> { saved_change_to_work_status? && !skip_notifications }
  
  # Флаг для отключения уведомлений (для тестов и массовых операций)
  attr_accessor :skip_notifications
  
  # Явно объявляем тип атрибута для enum
  attribute :work_status, :string, default: 'working'
  
  # Enum для рабочего состояния
  enum :work_status, {
    working: 'working',                    # работает в обычном режиме
    temporarily_closed: 'temporarily_closed', # временно закрыта
    maintenance: 'maintenance',            # плановое обслуживание  
    suspended: 'suspended'                 # приостановлена
  }
  
  # Custom setter для совместимости с фронтендом
  def services_attributes=(attributes)
    self.service_point_services_attributes = attributes
  end
  
  # Валидации
  validates :name, presence: true
  validates :address, presence: true
  validates :work_status, presence: true, inclusion: { in: work_statuses.keys }
  
  # Валидации для локализованных полей
  validates :name_ru, presence: true, length: { minimum: 2 }
  validates :name_uk, presence: true, length: { minimum: 2 }
  validates :description_ru, presence: true, length: { minimum: 10 }
  validates :description_uk, presence: true, length: { minimum: 10 }
  validates :address_ru, presence: true, length: { minimum: 5 }
  validates :address_uk, presence: true, length: { minimum: 5 }
  
  # Валидация: нельзя активировать сервисную точку, если партнер неактивен
  validate :partner_must_be_active_to_activate_service_point
  
  # Геолокация
  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true
  
  # Обновленные скоупы
  scope :active, -> { where(is_active: true) }                    # активные точки
  scope :inactive, -> { where(is_active: false) }                 # неактивные точки
  scope :working, -> { where(is_active: true, work_status: 'working') }  # работающие точки
  scope :available_for_booking, -> { active.where(work_status: ['working']) } # доступны для бронирования
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
  
  # Обновленные методы статусов
  def active?
    is_active?
  end
  
  def can_accept_bookings?
    is_active? && working?
  end
  
  def display_status
    return 'Неактивная' unless is_active?
    
    case work_status
    when 'working' then 'Работает'
    when 'temporarily_closed' then 'Временно закрыта'
    when 'maintenance' then 'Техническое обслуживание'
    when 'suspended' then 'Приостановлена'
    else work_status.humanize
    end
  end
  
  # Количество активных постов обслуживания
  def posts_count
    service_posts.active.count
  end
  
  def recalculate_metrics!
    update(
      total_clients_served: bookings.where(status: 'completed').count,
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
    
    service_point_services.create!(service_id: service_id)
  end
  
  # Удаляет услугу из списка доступных в этой точке
  def remove_service(service_id)
    service_point_services.find_by(service_id: service_id)&.destroy
  end
  
  # Метод для обновления рабочих часов из шаблонов расписания
  def update_working_hours_from_templates
    # Получаем все шаблоны расписания для этой точки
    templates = self.schedule_templates.includes(:weekday)
    
    # Создаем хеш для рабочих часов
    hours = {}
    
    # Дни недели на английском для соответствия формату working_hours
    day_names = {
      1 => 'monday',
      2 => 'tuesday',
      3 => 'wednesday',
      4 => 'thursday',
      5 => 'friday',
      6 => 'saturday',
      7 => 'sunday'
    }
    
    # Заполняем хеш рабочими часами из шаблонов
    templates.each do |template|
      day_key = day_names[template.weekday.sort_order]
      
      hours[day_key] = {
        'start' => template.is_working_day ? template.opening_time.strftime('%H:%M') : nil,
        'end' => template.is_working_day ? template.closing_time.strftime('%H:%M') : nil,
        'is_working_day' => template.is_working_day
      }
    end
    
    # Обновляем поле working_hours
    update_column(:working_hours, hours)
    
    hours
  end
  
  # Методы для работы с категориями услуг
  
  def posts_for_category(category_id)
    service_posts.active.by_category(category_id)
  end
  
  def posts_count_for_category(category_id)
    posts_for_category(category_id).count
  end
  
  def contact_phone_for_category(category_id)
    category_contacts.dig(category_id.to_s, 'phone')
  end
  
  def contact_email_for_category(category_id)
    category_contacts.dig(category_id.to_s, 'email')
  end
  
  def set_category_contact(category_id, phone:, email: nil)
    self.category_contacts = category_contacts.merge(
      category_id.to_s => { 'phone' => phone, 'email' => email }.compact
    )
  end
  
  def remove_category_contact(category_id)
    updated_contacts = category_contacts.dup
    updated_contacts.delete(category_id.to_s)
    self.category_contacts = updated_contacts
  end
  
  def supports_category?(category_id)
    posts_for_category(category_id).exists?
  end
  
  def available_categories
    service_posts.includes(:service_category).map(&:service_category).uniq
  end
  
  def category_statistics
    service_posts.joins(:service_category)
                 .group('service_categories.name')
                 .count
  end
  
  # Методы локализации согласно TABLE_LOCALIZATION_RULES.md
  def localized_name(locale = 'ru')
    case locale.to_s
    when 'uk'
      name_uk.presence || name_ru.presence || name.presence || ''
    when 'ru'
      name_ru.presence || name_uk.presence || name.presence || ''
    else
      name_ru.presence || name_uk.presence || name.presence || ''
    end
  end
  
  def localized_description(locale = 'ru')
    case locale.to_s
    when 'uk'
      description_uk.presence || description_ru.presence || description.presence || ''
    when 'ru'
      description_ru.presence || description_uk.presence || description.presence || ''
    else
      description_ru.presence || description_uk.presence || description.presence || ''
    end
  end
  
  def localized_address(locale = 'ru')
    case locale.to_s
    when 'uk'
      address_uk.presence || address_ru.presence || address.presence || ''
    when 'ru'
      address_ru.presence || address_uk.presence || address.presence || ''
    else
      address_ru.presence || address_uk.presence || address.presence || ''
    end
  end
  
  private
  
  # Валидация: нельзя активировать сервисную точку, если партнер неактивен
  def partner_must_be_active_to_activate_service_point
    if is_active? && partner.present? && !partner.is_active?
      errors.add(:is_active, 'нельзя активировать, так как партнер неактивен')
    end
  end
  
  def calculate_cancellation_rate
    total = bookings.count
    return 0.0 if total.zero?
    
    cancelled = bookings.where(status: ['cancelled_by_client', 'cancelled_by_partner', 'no_show']).count
    (cancelled.to_f / total) * 100
  end
  
  def analyze_booking_conflicts_if_status_changed
    # Анализируем конфликты если изменился статус активности или рабочий статус
    if saved_change_to_is_active? || saved_change_to_work_status?
      Rails.logger.info "ServicePoint #{id} status changed, scheduling conflict analysis"
      BookingConflictAnalysisJob.perform_later(service_point_id: id)
    end
  end
  
  private
  
  def renumber_service_posts
    service_posts.order(created_at: :asc).each_with_index do |post, index|
      post.update(post_number: index + 1)
    end
  end
  
  # Уведомление о создании новой сервисной точки
  def send_service_point_creation_notification
    # Email уведомление администраторам
    BookingNotificationJob.perform_later(id, 'admin_service_point_created', 'admin@test.com')
    
    # Telegram уведомление администраторам
    BookingNotificationJob.perform_later(id, 'telegram_admin_service_point_created')
    
    Rails.logger.info "🏢 Отправлены уведомления о создании сервисной точки ID: #{id}"
  end
  
  # Уведомление об изменении сервисной точки
  def send_service_point_change_notification
    # Email уведомление администраторам
    BookingNotificationJob.perform_later(id, 'admin_service_point_changed', 'admin@test.com')
    
    # Telegram уведомление администраторам
    BookingNotificationJob.perform_later(id, 'telegram_admin_service_point_changed')
    
    Rails.logger.info "🏢 Отправлены уведомления об изменении сервисной точки ID: #{id}"
  end
  
  # Уведомление об изменении статуса сервисной точки
  def send_service_point_status_change_notification
    # Email уведомление администраторам
    BookingNotificationJob.perform_later(id, 'admin_service_point_status_changed', 'admin@test.com')
    
    # Telegram уведомление администраторам
    BookingNotificationJob.perform_later(id, 'telegram_admin_service_point_status_changed')
    
    Rails.logger.info "🏢 Отправлены уведомления об изменении статуса сервисной точки ID: #{id} на #{work_status}"
  end
  
  # Проверка значимых изменений для уведомлений
  def significant_changes?
    significant_fields = %w[name address phone email latitude longitude is_active]
    significant_fields.any? { |field| saved_change_to_attribute?(field) }
  end
end
