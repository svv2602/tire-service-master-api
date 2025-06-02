# app/services/dynamic_availability_service.rb
# Сервис для динамического расчета доступности без создания физических слотов

class DynamicAvailabilityService
  # Интервал проверки в минутах (например, каждые 15 минут)
  TIME_INTERVAL = 15

  # Получение доступных временных интервалов для точки на дату
  def self.available_times_for_date(service_point_id, date, min_duration_minutes = nil)
    service_point = ServicePoint.find(service_point_id)
    
    # Получаем рабочие часы для данной даты
    schedule_info = get_schedule_for_date(service_point, date)
    return [] unless schedule_info[:is_working]
    
    # Преобразуем время из объектов Time в строки времени, затем создаем новые объекты с нужной датой
    opening_time_str = schedule_info[:opening_time].strftime('%H:%M:%S')
    closing_time_str = schedule_info[:closing_time].strftime('%H:%M:%S')
    
    start_time = Time.parse("#{date} #{opening_time_str}")
    end_time = Time.parse("#{date} #{closing_time_str}")
    total_posts = service_point.posts_count
    
    return [] if total_posts.zero?
    
    available_slots = []
    current_time = start_time
    
    # Проходим по всем временным интервалам дня
    while current_time < end_time
      occupied_posts = count_occupied_posts_at_time(service_point_id, date, current_time)
      available_posts = total_posts - occupied_posts
      
      if available_posts > 0
        # Проверяем минимальную длительность если задана
        if min_duration_minutes.nil? || has_enough_continuous_time?(service_point_id, date, current_time, min_duration_minutes)
          available_slots << {
            time: current_time.strftime('%H:%M'),
            datetime: current_time,
            available_posts: available_posts,
            total_posts: total_posts
          }
        end
      end
      
      current_time += TIME_INTERVAL.minutes
    end
    
    available_slots
  end

  # Проверка доступности конкретного времени
  def self.check_availability_at_time(service_point_id, date, time, duration_minutes = 60)
    service_point = ServicePoint.find(service_point_id)
    
    # Проверяем рабочие часы
    schedule_info = get_schedule_for_date(service_point, date)
    return { available: false, reason: 'Не рабочий день' } unless schedule_info[:is_working]
    
    # Преобразуем время из объектов Time в строки времени, затем создаем новые объекты с нужной датой
    opening_time_str = schedule_info[:opening_time].strftime('%H:%M:%S')
    closing_time_str = schedule_info[:closing_time].strftime('%H:%M:%S')
    
    opening_time = Time.parse("#{date} #{opening_time_str}")
    closing_time = Time.parse("#{date} #{closing_time_str}")
    check_time = time.is_a?(String) ? Time.parse("#{date} #{time}") : time
    
    return { available: false, reason: 'Вне рабочих часов' } if check_time < opening_time || check_time >= closing_time
    
    # Проверяем что время + длительность не выходит за рабочие часы
    end_time = check_time + duration_minutes.minutes
    return { available: false, reason: 'Недостаточно времени до закрытия' } if end_time > closing_time
    
    total_posts = service_point.posts_count
    return { available: false, reason: 'Нет активных постов' } if total_posts.zero?
    
    # Проверяем доступность на весь период бронирования
    current_time = check_time
    while current_time < end_time
      occupied_posts = count_occupied_posts_at_time(service_point_id, date, current_time)
      available_posts = total_posts - occupied_posts
      
      if available_posts <= 0
        return { 
          available: false, 
          reason: "Все посты заняты в #{current_time.strftime('%H:%M')}"
        }
      end
      
      current_time += TIME_INTERVAL.minutes
    end
    
    {
      available: true,
      total_posts: total_posts,
      occupied_posts: count_occupied_posts_at_time(service_point_id, date, check_time)
    }
  end

  # Поиск ближайшего доступного времени
  def self.find_next_available_time(service_point_id, date, after_time = nil, duration_minutes = 60)
    after_time ||= Time.current
    
    # Ищем в текущем дне
    today_slots = available_times_for_date(service_point_id, date, duration_minutes)
    
    today_available = today_slots.find do |slot|
      slot[:datetime] >= after_time
    end
    
    return today_available if today_available
    
    # Ищем в следующих днях (до 30 дней вперед)
    (1..30).each do |days_ahead|
      future_date = date + days_ahead.days
      future_slots = available_times_for_date(service_point_id, future_date, duration_minutes)
      
      return future_slots.first if future_slots.any?
    end
    
    nil
  end

  # Получение детальной информации о загрузке на день
  def self.day_occupancy_details(service_point_id, date)
    service_point = ServicePoint.find(service_point_id)
    schedule_info = get_schedule_for_date(service_point, date)
    
    return { is_working: false } unless schedule_info[:is_working]
    
    # Преобразуем время из объектов Time в строки времени, затем создаем новые объекты с нужной датой
    opening_time_str = schedule_info[:opening_time].strftime('%H:%M:%S')
    closing_time_str = schedule_info[:closing_time].strftime('%H:%M:%S')
    
    start_time = Time.parse("#{date} #{opening_time_str}")
    end_time = Time.parse("#{date} #{closing_time_str}")
    total_posts = service_point.posts_count
    
    intervals = []
    current_time = start_time
    
    while current_time < end_time
      occupied_posts = count_occupied_posts_at_time(service_point_id, date, current_time)
      available_posts = total_posts - occupied_posts
      
      intervals << {
        time: current_time.strftime('%H:%M'),
        occupied_posts: occupied_posts,
        available_posts: available_posts,
        occupancy_rate: total_posts > 0 ? (occupied_posts.to_f / total_posts * 100).round(1) : 0
      }
      
      current_time += TIME_INTERVAL.minutes
    end
    
    {
      is_working: true,
      opening_time: schedule_info[:opening_time].strftime('%H:%M'),
      closing_time: schedule_info[:closing_time].strftime('%H:%M'),
      total_posts: total_posts,
      intervals: intervals,
      summary: calculate_day_summary(intervals)
    }
  end

  private

  # Получение рабочих часов для даты с учетом шаблонов и исключений
  def self.get_schedule_for_date(service_point, date)
    # Проверяем исключения (праздники, особые дни)
    exception = service_point.schedule_exceptions.find_by(exception_date: date)
    if exception
      return {
        is_working: !exception.is_closed,
        opening_time: exception.opening_time,
        closing_time: exception.closing_time
      }
    end
    
    # Получаем шаблон для дня недели
    weekday = Weekday.find_by(sort_order: date.wday == 0 ? 7 : date.wday)
    template = service_point.schedule_templates.find_by(weekday: weekday)
    
    if template && template.is_working_day
      {
        is_working: true,
        opening_time: template.opening_time,
        closing_time: template.closing_time
      }
    else
      { is_working: false }
    end
  end

  # Подсчет занятых постов в конкретное время
  def self.count_occupied_posts_at_time(service_point_id, date, time)
    # Преобразуем время в строковый формат для сравнения с полями времени в БД
    time_string = time.strftime('%H:%M:%S')
    
    # Считаем бронирования, которые пересекаются с указанным временем
    # Используем EXTRACT для получения времени из datetime полей и сравниваем
    Booking.where(service_point_id: service_point_id)
           .where(booking_date: date)
           .where("EXTRACT(hour FROM start_time) * 60 + EXTRACT(minute FROM start_time) <= ? AND EXTRACT(hour FROM end_time) * 60 + EXTRACT(minute FROM end_time) > ?", 
                  time.hour * 60 + time.min, 
                  time.hour * 60 + time.min)
           .where.not(status_id: BookingStatus.canceled_statuses)
           .count
  end

  # Проверка наличия непрерывного времени для бронирования
  def self.has_enough_continuous_time?(service_point_id, date, start_time, duration_minutes)
    end_time = start_time + duration_minutes.minutes
    current_time = start_time
    
    while current_time < end_time
      availability = check_availability_at_time(service_point_id, date, current_time, TIME_INTERVAL)
      return false unless availability[:available]
      
      current_time += TIME_INTERVAL.minutes
    end
    
    true
  end

  # Расчет сводки по дню
  def self.calculate_day_summary(intervals)
    return {} if intervals.empty?
    
    total_intervals = intervals.count
    busy_intervals = intervals.count { |i| i[:available_posts] == 0 }
    avg_occupancy = intervals.sum { |i| i[:occupancy_rate] } / total_intervals
    
    {
      total_intervals: total_intervals,
      busy_intervals: busy_intervals,
      free_intervals: total_intervals - busy_intervals,
      average_occupancy_rate: avg_occupancy.round(1),
      peak_occupancy_rate: intervals.map { |i| i[:occupancy_rate] }.max
    }
  end
end 