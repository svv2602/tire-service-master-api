class SeasonalSchedule < ApplicationRecord
  # Связи
  belongs_to :service_point
  
  # Валидации
  validates :name, presence: true, length: { maximum: 255 }
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :working_hours, presence: true
  validates :priority, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  validate :end_date_after_start_date
  validate :working_hours_format
  validate :no_overlapping_periods
  
  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :by_priority, -> { order(priority: :desc) }
  scope :current, -> { where('start_date <= ? AND end_date >= ?', Date.current, Date.current) }
  scope :upcoming, -> { where('start_date > ?', Date.current) }
  scope :past, -> { where('end_date < ?', Date.current) }
  scope :overlapping, ->(start_date, end_date) {
    where('start_date <= ? AND end_date >= ?', end_date, start_date)
  }
  
  # Методы
  
  # Проверяет, активно ли расписание на указанную дату
  def active_on_date?(date)
    is_active && start_date <= date && end_date >= date
  end
  
  # Получает расписание для указанного дня недели
  def schedule_for_day(day_key)
    return nil unless working_hours.is_a?(Hash)
    working_hours[day_key.to_s] || working_hours[day_key.to_sym]
  end
  
  # Проверяет, является ли день рабочим
  def working_day?(day_key)
    day_schedule = schedule_for_day(day_key)
    return false unless day_schedule
    day_schedule['is_working_day'] == true || day_schedule['is_working_day'] == 'true'
  end
  
  # Получает время начала работы для дня
  def start_time_for_day(day_key)
    day_schedule = schedule_for_day(day_key)
    return nil unless day_schedule && working_day?(day_key)
    day_schedule['start']
  end
  
  # Получает время окончания работы для дня
  def end_time_for_day(day_key)
    day_schedule = schedule_for_day(day_key)
    return nil unless day_schedule && working_day?(day_key)
    day_schedule['end']
  end
  
  # Получает количество рабочих дней в расписании
  def working_days_count
    return 0 unless working_hours.is_a?(Hash)
    
    working_hours.count do |day, schedule|
      schedule.is_a?(Hash) && (schedule['is_working_day'] == true || schedule['is_working_day'] == 'true')
    end
  end
  
  # Получает период действия в читаемом формате
  def period_description
    if start_date == end_date
      "#{start_date.strftime('%d.%m.%Y')}"
    else
      "#{start_date.strftime('%d.%m.%Y')} - #{end_date.strftime('%d.%m.%Y')}"
    end
  end
  
  # Статические методы
  
  # Находит активное сезонное расписание для сервисной точки на указанную дату
  def self.find_active_for_date(service_point_id, date)
    where(service_point_id: service_point_id)
      .active
      .where('start_date <= ? AND end_date >= ?', date, date)
      .by_priority
      .first
  end
  
  # Находит все активные сезонные расписания для сервисной точки на указанный период
  def self.find_active_for_period(service_point_id, start_date, end_date)
    where(service_point_id: service_point_id)
      .active
      .overlapping(start_date, end_date)
      .by_priority
  end
  
  private
  
  # Валидация корректности дат
  def end_date_after_start_date
    return unless start_date && end_date
    
    if end_date < start_date
      errors.add(:end_date, 'должна быть больше или равна дате начала')
    end
  end
  
  # Валидация формата working_hours
  def working_hours_format
    return unless working_hours
    
    unless working_hours.is_a?(Hash)
      errors.add(:working_hours, 'должно быть объектом')
      return
    end
    
    valid_days = %w[monday tuesday wednesday thursday friday saturday sunday]
    
    working_hours.each do |day, schedule|
      unless valid_days.include?(day.to_s)
        errors.add(:working_hours, "содержит недопустимый день недели: #{day}")
        next
      end
      
      unless schedule.is_a?(Hash)
        errors.add(:working_hours, "расписание для #{day} должно быть объектом")
        next
      end
      
      # Проверяем обязательные поля
      unless schedule.key?('is_working_day') || schedule.key?(:is_working_day)
        errors.add(:working_hours, "отсутствует поле is_working_day для #{day}")
        next
      end
      
      is_working = schedule['is_working_day'] || schedule[:is_working_day]
      
      # Если день рабочий, проверяем наличие времени
      if is_working == true || is_working == 'true'
        start_time = schedule['start'] || schedule[:start]
        end_time = schedule['end'] || schedule[:end]
        
        if start_time.blank?
          errors.add(:working_hours, "отсутствует время начала работы для #{day}")
        end
        
        if end_time.blank?
          errors.add(:working_hours, "отсутствует время окончания работы для #{day}")
        end
        
        # Проверяем формат времени
        if start_time.present? && !start_time.match?(/^\d{2}:\d{2}$/)
          errors.add(:working_hours, "некорректный формат времени начала для #{day}")
        end
        
        if end_time.present? && !end_time.match?(/^\d{2}:\d{2}$/)
          errors.add(:working_hours, "некорректный формат времени окончания для #{day}")
        end
        
        # Проверяем, что время окончания больше времени начала
        if start_time.present? && end_time.present? && start_time >= end_time
          errors.add(:working_hours, "время окончания должно быть больше времени начала для #{day}")
        end
      end
    end
  end
  
  # Валидация на отсутствие пересекающихся периодов с тем же приоритетом
  def no_overlapping_periods
    return unless service_point_id && start_date && end_date
    
    overlapping_schedules = SeasonalSchedule
      .where(service_point_id: service_point_id)
      .where.not(id: id) # Исключаем текущую запись при обновлении
      .active
      .where(priority: priority)
      .overlapping(start_date, end_date)
    
    if overlapping_schedules.exists?
      errors.add(:base, 'Период пересекается с другим сезонным расписанием того же приоритета')
    end
  end
end 