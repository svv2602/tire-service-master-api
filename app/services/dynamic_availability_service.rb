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
    # Проверяем наличие бронирований, которые пересекаются с этим слотом
    Booking.where(
      service_point_id: service_point_id, 
      booking_date: date
    ).where(
      "start_time < ? AND end_time > ?", 
      end_time.strftime('%H:%M:%S'), 
      start_time.strftime('%H:%M:%S')
    ).where.not(
      status_id: BookingStatus.canceled_statuses
    ).exists?
    
    # Примечание: Убрали зависимость от schedule_slots, так как генерируем слоты динамически
    # На основе рабочих часов постов. Проверяем только пересечения с бронированиями.
  end
  
  # Группировка слотов постов по времени с агрегацией доступности
  def self.available_times_for_date(service_point_id, date, min_duration_minutes = nil)
    service_point = ServicePoint.find(service_point_id)
    
    # Получаем рабочие часы для данной даты
    schedule_info = get_schedule_for_date(service_point, date)
    return [] unless schedule_info[:is_working]
    
    # Получаем все доступные слоты от постов
    individual_slots = available_slots_for_date(service_point_id, date)
    return [] if individual_slots.empty?
    
    # Получаем общее количество активных постов для этого дня
    day_key = case date.wday
    when 0 then 'sunday'
    when 1 then 'monday'
    when 2 then 'tuesday'
    when 3 then 'wednesday'
    when 4 then 'thursday'
    when 5 then 'friday'
    when 6 then 'saturday'
    end
    
    total_posts = service_point.service_posts.active.select do |post|
      if post.has_custom_schedule && post.working_days.present?
        post.working_days[day_key] == true || post.working_days[day_key.to_s] == true
      else
        # Пост работает по расписанию точки
        day_schedule = service_point.working_hours[day_key]
        day_schedule.present? && (day_schedule['is_working_day'] == true || day_schedule['is_working_day'] == 'true')
      end
    end.count
    
    # Группируем слоты по времени начала
    grouped_slots = individual_slots.group_by { |slot| slot[:start_time] }
    
    # Создаем агрегированные временные слоты
    available_time_slots = grouped_slots.map do |time, slots|
      # Считаем сколько постов доступно в это время
      available_posts_count = slots.count
      
      # Проверяем минимальную длительность если задана
      if min_duration_minutes.nil? || slots.any? { |slot| slot[:duration_minutes] >= min_duration_minutes }
        {
          time: time,
          datetime: slots.first[:datetime],
          available_posts: available_posts_count,
          total_posts: total_posts
        }
      else
        nil
      end
    end.compact
    
    # Сортируем по времени
    available_time_slots.sort_by { |slot| slot[:datetime] }
  end

  # Проверка доступности конкретного времени
  def self.check_availability_at_time(service_point_id, date, time, duration_minutes = 60, exclude_booking_id: nil)
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
    
    # Получаем доступные слоты для проверки реальной доступности
    available_slots = available_slots_for_date(service_point_id, date)
    
    # Ищем слот, который начинается в указанное время
    matching_slot = available_slots.find { |slot| slot[:start_time] == check_time.strftime('%H:%M') }
    
    # Если нет слота в указанное время, проверяем доступность по старой логике
    unless matching_slot
      end_time = check_time + duration_minutes.minutes
      return { available: false, reason: 'Недостаточно времени до закрытия' } if end_time > closing_time
    else
      # Если есть слот, проверяем, достаточно ли его длительности
      slot_duration = matching_slot[:duration_minutes]
      if duration_minutes > slot_duration
        return { 
          available: false, 
          reason: "Недостаточная длительность слота (доступно #{slot_duration} мин, требуется #{duration_minutes} мин)",
          available_duration: slot_duration,
          requested_duration: duration_minutes
        }
      end
    end
    
    # Получаем количество активных постов, работающих в этот день
    day_key = case date.wday
    when 0 then 'sunday'
    when 1 then 'monday'
    when 2 then 'tuesday'
    when 3 then 'wednesday'
    when 4 then 'thursday'
    when 5 then 'friday'
    when 6 then 'saturday'
    end
    
    total_posts = service_point.service_posts.active.select do |post|
      if post.has_custom_schedule && post.working_days.present?
        post.working_days[day_key] == true || post.working_days[day_key.to_s] == true
      else
        # Пост работает по расписанию точки
        day_schedule = service_point.working_hours[day_key]
        day_schedule.present? && (day_schedule['is_working_day'] == true || day_schedule['is_working_day'] == 'true')
      end
    end.count
    
    return { available: false, reason: 'Нет активных постов' } if total_posts.zero?
    
    # Определяем время окончания бронирования
    if matching_slot
      # Используем длительность слота
      end_time = check_time + matching_slot[:duration_minutes].minutes
    else
      # Используем переданную длительность
      end_time = check_time + duration_minutes.minutes
    end
    
    # Проверяем доступность на весь период бронирования
    current_time = check_time
    while current_time < end_time
      occupied_posts = count_occupied_posts_at_time(service_point_id, date, current_time, exclude_booking_id: exclude_booking_id)
      available_posts = total_posts - occupied_posts
      
      if available_posts <= 0
        return { 
          available: false, 
          reason: "Все посты заняты в #{current_time.strftime('%H:%M')}",
          total_posts: total_posts,
          occupied_posts: occupied_posts,
          available_posts: available_posts
        }
      end
      
      current_time += MIN_TIME_INTERVAL.minutes
    end
    
    {
      available: true,
      total_posts: total_posts,
      occupied_posts: count_occupied_posts_at_time(service_point_id, date, check_time, exclude_booking_id: exclude_booking_id),
      available_posts: total_posts - count_occupied_posts_at_time(service_point_id, date, check_time, exclude_booking_id: exclude_booking_id)
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

  # Получение детальной информации о загрузке на день (по слотам бронирования)
  def self.day_occupancy_details(service_point_id, date)
    service_point = ServicePoint.find(service_point_id)
    schedule_info = get_schedule_for_date(service_point, date)
    
    return { is_working: false } unless schedule_info[:is_working]
    
    # Получаем все доступные слоты для этого дня
    available_slots = available_slots_for_date(service_point_id, date)
    
    # Получаем все возможные слоты (доступные + занятые)
    all_possible_slots = get_all_possible_slots_for_date(service_point_id, date)
    
    total_slots = all_possible_slots.count
    available_slots_count = available_slots.count
    occupied_slots_count = total_slots - available_slots_count
    
    occupancy_percentage = total_slots > 0 ? (occupied_slots_count.to_f / total_slots * 100).round(1) : 0
    
    {
      is_working: true,
      opening_time: schedule_info[:opening_time].strftime('%H:%M'),
      closing_time: schedule_info[:closing_time].strftime('%H:%M'),
      total_posts: service_point.service_posts.active.count,
      summary: {
        total_slots: total_slots,
        available_slots: available_slots_count,
        occupied_slots: occupied_slots_count,
        occupancy_percentage: occupancy_percentage,
        total_intervals: total_slots,
        busy_intervals: occupied_slots_count,
        free_intervals: available_slots_count,
        average_occupancy_rate: occupancy_percentage,
        peak_occupancy_rate: occupancy_percentage
      }
    }
  end

  # Получение всех возможных слотов для дня (включая занятые)
  def self.get_all_possible_slots_for_date(service_point_id, date)
    service_point = ServicePoint.find(service_point_id)
    
    # Получаем рабочие часы для данной даты
    schedule_info = get_schedule_for_date(service_point, date)
    return [] unless schedule_info[:is_working]
    
    # Определяем день недели
    day_key = date.strftime('%A').downcase
    
    all_slots = []
    
    # Проходим по всем активным постам
    service_point.service_posts.active.ordered_by_post_number.each do |service_post|
      # Проверяем, работает ли пост в этот день
      next unless service_post.working_on_day?(day_key)
      
      # Определяем время работы поста
      start_time_str = service_post.start_time_for_day(day_key)
      end_time_str = service_post.end_time_for_day(day_key)
      
      start_time = Time.parse("#{date} #{start_time_str}")
      end_time = Time.parse("#{date} #{end_time_str}")
      
      # Генерируем все возможные слоты с индивидуальной длительностью
      current_time = start_time
      while current_time + service_post.slot_duration.minutes <= end_time
        slot_end_time = current_time + service_post.slot_duration.minutes
        
        all_slots << {
          service_post_id: service_post.id,
          post_number: service_post.post_number,
          post_name: service_post.name,
          start_time: current_time.strftime('%H:%M'),
          end_time: slot_end_time.strftime('%H:%M'),
          duration_minutes: service_post.slot_duration,
          datetime: current_time
        }
        
        current_time = slot_end_time
      end
    end
    
    # Сортируем по времени
    all_slots.sort_by { |slot| slot[:datetime] }
  end

  private

  # Получение рабочих часов для даты с учетом working_hours
  def self.get_schedule_for_date(service_point, date)
    return { is_working: false } unless service_point.working_hours.present?
    
    # Определяем день недели в формате для working_hours
    day_key = case date.wday
    when 0 then 'sunday'
    when 1 then 'monday'
    when 2 then 'tuesday'
    when 3 then 'wednesday'
    when 4 then 'thursday'
    when 5 then 'friday'
    when 6 then 'saturday'
    end
    
    day_schedule = service_point.working_hours[day_key]
    return { is_working: false } unless day_schedule.present?
    
    is_working = day_schedule['is_working_day'] == true || day_schedule['is_working_day'] == 'true'
    return { is_working: false } unless is_working
    
    begin
      opening_time = Time.parse("#{date} #{day_schedule['start']}:00")
      closing_time = Time.parse("#{date} #{day_schedule['end']}:00")
      
      {
        is_working: true,
        opening_time: opening_time,
        closing_time: closing_time
      }
    rescue => e
      Rails.logger.error "DynamicAvailabilityService: Ошибка парсинга времени для точки #{service_point.id}, день #{day_key}: #{e.message}"
      { is_working: false }
    end
  end

  # Подсчет занятых постов в конкретное время
  def self.count_occupied_posts_at_time(service_point_id, date, time, exclude_booking_id: nil)
    # Преобразуем время в строковый формат для сравнения с полями времени в БД
    time_string = time.strftime('%H:%M:%S')
    
    query = Booking.where(
      service_point_id: service_point_id,
      booking_date: date
    ).where(
      "start_time <= ? AND end_time > ?",
      time_string,
      time_string
    ).where.not(status_id: BookingStatus.canceled_statuses)
    
    # Исключаем конкретное бронирование если указано
    query = query.where.not(id: exclude_booking_id) if exclude_booking_id.present?
    
    query.count
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