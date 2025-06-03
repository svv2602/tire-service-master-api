# Модель для индивидуальных постов обслуживания с настройками времени
class ServicePost < ApplicationRecord
  belongs_to :service_point
  has_many :schedule_slots, dependent: :destroy
  
  # Валидации
  validates :post_number, presence: true
  validates :post_number, numericality: { greater_than: 0, 
                                         message: "Номер поста должен быть положительным числом" }
  validate :unique_post_number_within_service_point
  validates :name, presence: true, length: { maximum: 255 }
  validates :slot_duration, presence: true, 
            numericality: { greater_than: 15, less_than_or_equal_to: 480,
                           message: "Длительность слота должна быть от 15 минут до 8 часов" }
  
  # Скоупы для удобного поиска
  scope :active, -> { where(is_active: true) }
  scope :for_service_point, ->(service_point_id) { where(service_point: service_point_id) }
  scope :ordered_by_post_number, -> { order(:post_number) }
  
  # Метод для получения длительности в секундах
  def slot_duration_in_seconds
    slot_duration * 60
  end
  
  # Метод для форматированного отображения поста
  def display_name
    "Пост #{post_number}#{name.present? ? " - #{name}" : ""}"
  end
  
  # Проверка доступности поста
  def available?
    is_active?
  end
  
  # Метод для получения следующего доступного времени
  def next_available_slot_start_time(from_time = Time.current)
    # Логика будет реализована позже в ScheduleManager
    from_time
  end
  
  # Получает доступные слоты для этого поста на указанную дату
  def available_slots_for_date(date)
    schedule_slots.where(slot_date: date, is_available: true)
                  .left_joins(:bookings)
                  .where(bookings: { id: nil })
                  .order(start_time: :asc)
  end
  
  # Получает статистику загруженности поста за период
  def occupancy_rate_for_period(start_date, end_date)
    total_slots = schedule_slots.where(slot_date: start_date..end_date).count
    return 0.0 if total_slots.zero?
    
    booked_slots = schedule_slots.where(slot_date: start_date..end_date)
                                 .joins(:bookings)
                                 .count
    
    (booked_slots.to_f / total_slots * 100).round(2)
  end

  private

  # Собственная валидация уникальности post_number которая игнорирует записи помеченные на удаление
  def unique_post_number_within_service_point
    return if marked_for_destruction? # Не валидируем если запись помечена на удаление
    return if post_number.blank? || service_point_id.blank?

    # Проверяем есть ли другие посты с таким же номером в той же сервисной точке
    # Исключаем текущую запись если она уже сохранена
    existing_posts = ServicePost.where(service_point_id: service_point_id, post_number: post_number)
    existing_posts = existing_posts.where.not(id: id) if persisted?
    
    if existing_posts.exists?
      errors.add(:post_number, "Номер поста должен быть уникальным в рамках точки обслуживания")
    end
  end
end
