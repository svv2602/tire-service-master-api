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
  
  # Валидации для индивидуального расписания
  validate :validate_working_days_format, if: :has_custom_schedule?
  validate :validate_custom_hours_format, if: :has_custom_schedule?
  validate :at_least_one_working_day, if: :has_custom_schedule?
  
  # Скоупы для удобного поиска
  scope :active, -> { where(is_active: true) }
  scope :for_service_point, ->(service_point_id) { where(service_point: service_point_id) }
  scope :ordered_by_post_number, -> { order(:post_number) }
  scope :with_custom_schedule, -> { where(has_custom_schedule: true) }
  
  # Методы для работы с индивидуальным расписанием
  
  # Проверяет, работает ли пост в указанный день недели
  def working_on_day?(day_key)
    return true unless has_custom_schedule?
    return true if working_days.blank?
    
    working_days[day_key.to_s] == true
  end
  
  # Получает время начала работы поста для указанного дня
  def start_time_for_day(day_key)
    if has_custom_schedule? && custom_hours.present?
      custom_hours['start']
    else
      service_point.working_hours&.dig(day_key.to_s, 'start') || '09:00'
    end
  end
  
  # Получает время окончания работы поста для указанного дня
  def end_time_for_day(day_key)
    if has_custom_schedule? && custom_hours.present?
      custom_hours['end']
    else
      service_point.working_hours&.dig(day_key.to_s, 'end') || '18:00'
    end
  end
  
  # Проверяет доступность поста в указанное время
  def available_at_time?(datetime)
    return false unless is_active?
    
    day_key = datetime.strftime('%A').downcase # monday, tuesday, etc.
    return false unless working_on_day?(day_key)
    
    time_str = datetime.strftime('%H:%M')
    start_time = start_time_for_day(day_key)
    end_time = end_time_for_day(day_key)
    
    time_str >= start_time && time_str < end_time
  end
  
  # Получает список рабочих дней недели
  def working_days_list
    return [] unless has_custom_schedule? && working_days.present?
    
    working_days.select { |_, is_working| is_working }.keys
  end
  
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
  
  # Валидация формата working_days
  def validate_working_days_format
    return unless working_days.present?
    
    valid_days = %w[monday tuesday wednesday thursday friday saturday sunday]
    
    unless working_days.is_a?(Hash)
      errors.add(:working_days, 'должно быть объектом')
      return
    end
    
    working_days.each do |day, value|
      unless valid_days.include?(day.to_s)
        errors.add(:working_days, "содержит недопустимый день недели: #{day}")
      end
      
      unless [true, false].include?(value)
        errors.add(:working_days, "значение для #{day} должно быть true или false")
      end
    end
  end
  
  # Валидация формата custom_hours
  def validate_custom_hours_format
    return unless custom_hours.present?
    
    unless custom_hours.is_a?(Hash)
      errors.add(:custom_hours, 'должно быть объектом')
      return
    end
    
    required_keys = %w[start end]
    required_keys.each do |key|
      unless custom_hours[key].present?
        errors.add(:custom_hours, "должно содержать поле #{key}")
      else
        unless valid_time_format?(custom_hours[key])
          errors.add(:custom_hours, "#{key} должно быть в формате HH:MM")
        end
      end
    end
    
    # Проверяем что время начала меньше времени окончания
    if custom_hours['start'].present? && custom_hours['end'].present? &&
       valid_time_format?(custom_hours['start']) && valid_time_format?(custom_hours['end'])
      
      start_time = Time.parse("2024-01-01 #{custom_hours['start']}")
      end_time = Time.parse("2024-01-01 #{custom_hours['end']}")
      
      if start_time >= end_time
        errors.add(:custom_hours, 'время начала должно быть меньше времени окончания')
      end
    end
  end
  
  # Проверка что выбран хотя бы один рабочий день
  def at_least_one_working_day
    return unless working_days.present?
    return unless working_days.is_a?(Hash) # Проверяем что это хэш перед вызовом values
    
    unless working_days.values.any? { |v| v == true }
      errors.add(:working_days, 'должен быть выбран хотя бы один рабочий день')
    end
  end
  
  # Проверка формата времени
  def valid_time_format?(time_string)
    time_string.match?(/\A\d{2}:\d{2}\z/)
  end
end
