# app/services/dynamic_availability_service.rb
# Сервис для динамического расчета доступности без создания физических слотов

class DynamicAvailabilityService
  # Минимальный интервал проверки в минутах (для обратной совместимости)
  MIN_TIME_INTERVAL = 15

  # Получение доступных временных слотов с учетом индивидуальных интервалов постов
  def self.available_slots_for_date(service_point_id, date)
    service_point = ServicePoint.find(service_point_id)
    
    # Получаем рабочие часы для данной даты
    schedule_info = get_schedule_for_date(service_point, date)
    return [] unless schedule_info[:is_working]
    
    # Определяем день недели
    day_key = date.strftime('%A').downcase
    
    available_slots = []
    
    # Проходим по всем активным постам
    service_point.service_posts.active.ordered_by_post_number.each do |service_post|
      # Проверяем, работает ли пост в этот день
      next unless service_post.working_on_day?(day_key)
      
      # Определяем время работы поста
      start_time_str = service_post.start_time_for_day(day_key)
      end_time_str = service_post.end_time_for_day(day_key)
      
      start_time = Time.parse("#{date} #{start_time_str}")
      end_time = Time.parse("#{date} #{end_time_str}")
      
      # Генерируем слоты с индивидуальной длительностью
      current_time = start_time
      while current_time + service_post.slot_duration.minutes <= end_time
        slot_end_time = current_time + service_post.slot_duration.minutes
        
        # Проверяем доступность слота
        is_available = !is_slot_occupied?(service_point_id, service_post.id, date, current_time, slot_end_time)
        
        if is_available
          available_slots << {
            service_post_id: service_post.id,
            post_number: service_post.post_number,
            post_name: service_post.name,
            start_time: current_time.strftime('%H:%M'),
            end_time: slot_end_time.strftime('%H:%M'),
            duration_minutes: service_post.slot_duration,
            datetime: current_time
          }
        end
        
        current_time = slot_end_time
      end
    end
    
    # Сортируем по времени
    available_slots.sort_by { |slot| slot[:datetime] }
  end
  
  # Проверяет, занят ли слот для конкретного поста
  def self.is_slot_occupied?(service_point_id, service_post_id, date, start_time, end_time)
    # Проверяем если есть слот в базе данных и он занят
    slot = ScheduleSlot.find_by(
      service_point_id: service_point_id,
      service_post_id: service_post_id,
      slot_date: date,
      start_time: start_time.strftime('%H:%M:%S'),
      end_time: end_time.strftime('%H:%M:%S')
    )
    
    # Если слота нет в базе, считаем что он недоступен
    return true unless slot
    
    # Если слот отмечен как недоступный
    return true unless slot.is_available
    
    # Проверяем наличие бронирований в это время
    Booking.where(service_point_id: service_point_id, booking_date: date)
           .where("start_time < ? AND end_time > ?", end_time.strftime('%H:%M:%S'), start_time.strftime('%H:%M:%S'))
           .where.not(status_id: BookingStatus.canceled_statuses)
           .exists?
  end
  
  # Обратная совместимость: старый метод с фиксированным интервалом
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
      
      current_time += MIN_TIME_INTERVAL.minutes
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
      
      current_time += MIN_TIME_INTERVAL.minutes
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
      
      current_time += MIN_TIME_INTERVAL.minutes
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

  # Получение рабочих часов для даты с учетом working_hours
  def self.get_schedule_for_date(service_point, date)
    # Определяем день недели
    day_key = date.strftime('%A').downcase # monday, tuesday, etc.
    
    # Проверяем рабочие часы сервисной точки
    working_hours = service_point.working_hours
    if working_hours.blank? || working_hours[day_key].blank?
      return { is_working: false }
    end
    
    day_schedule = working_hours[day_key]
    is_working_day = day_schedule['is_working_day'] == 'true' || day_schedule['is_working_day'] == true
    
    if is_working_day
      {
        is_working: true,
        opening_time: Time.parse("2024-01-01 #{day_schedule['start']}"),
        closing_time: Time.parse("2024-01-01 #{day_schedule['end']}")
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
      availability = check_availability_at_time(service_point_id, date, current_time, MIN_TIME_INTERVAL)
      return false unless availability[:available]
      
      current_time += MIN_TIME_INTERVAL.minutes
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