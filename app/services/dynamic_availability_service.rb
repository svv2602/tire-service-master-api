# app/services/dynamic_availability_service.rb
# Сервис для динамического расчета доступности без создания физических слотов

class DynamicAvailabilityService
  # Минимальный интервал проверки в минутах (для обратной совместимости)
  MIN_TIME_INTERVAL = 15

  # Получение ВСЕХ временных слотов с указанием их доступности (новый подход)
  def self.all_slots_for_date(service_point_id, date)
    service_point = ServicePoint.find(service_point_id)
    
    # Проверяем есть ли работающие посты в этот день (новая логика)
    return [] unless has_any_working_posts_on_date?(service_point, date)
    
    # Определяем день недели
    day_key = case date.wday
    when 0 then 'sunday'
    when 1 then 'monday'
    when 2 then 'tuesday'
    when 3 then 'wednesday'
    when 4 then 'thursday'
    when 5 then 'friday'
    when 6 then 'saturday'
    end
    
    # Получаем расписание для этой даты (с учетом сезонных расписаний)
    schedule_info = get_schedule_for_date(service_point, date)
    
    # Получаем все активные посты, работающие в этот день
    working_posts = service_point.service_posts.active.select do |post|
      if post.has_custom_schedule && post.working_days.present?
        # Посты с индивидуальным расписанием не затрагиваются сезонными расписаниями
        post.working_days[day_key] == true || post.working_days[day_key.to_s] == true
      else
        # Пост работает по расписанию точки (включая сезонные расписания)
        schedule_info[:is_working]
      end
    end
    
    return [] if working_posts.empty?
    
    # Берем параметры от первого поста (предполагаем что все посты одинаковые)
    first_post = working_posts.first
    total_posts_count = working_posts.count
    
    # Определяем время работы
    if first_post.has_custom_schedule && first_post.working_days.present?
      # Пост с индивидуальным расписанием - используем его время
      start_time_str = first_post.start_time_for_day(day_key)
      end_time_str = first_post.end_time_for_day(day_key)
    else
      # Пост работает по общему расписанию - используем время из schedule_info (включая сезонные)
      if schedule_info[:opening_time] && schedule_info[:closing_time]
        start_time_str = schedule_info[:opening_time].strftime('%H:%M')
        end_time_str = schedule_info[:closing_time].strftime('%H:%M')
      else
        # Fallback на время поста
        start_time_str = first_post.start_time_for_day(day_key)
        end_time_str = first_post.end_time_for_day(day_key)
      end
    end
    
    slot_duration = first_post.slot_duration
    
    start_time = Time.parse("#{date} #{start_time_str}")
    end_time = Time.parse("#{date} #{end_time_str}")
    
    # Генерируем все временные слоты
    all_slots = []
    current_time = start_time
    
    while current_time + slot_duration.minutes <= end_time
      slot_end_time = current_time + slot_duration.minutes
      
      # Подсчитываем количество бронирований в это время
      bookings_count = count_bookings_at_time(service_point_id, date, current_time, slot_end_time)
      
      # Создаем слоты для каждого доступного поста
      (1..total_posts_count).each do |post_index|
        is_available = post_index > bookings_count
        
        all_slots << {
          service_post_id: working_posts[post_index - 1]&.id,
          post_number: post_index,
          post_name: "Пост #{post_index}",
          start_time: current_time.strftime('%H:%M'),
          end_time: slot_end_time.strftime('%H:%M'),
          duration_minutes: slot_duration,
          datetime: current_time,
          available: is_available,
          bookings_count: bookings_count,
          total_posts: total_posts_count
        }
      end
      
      current_time = slot_end_time
    end
    
    # Сортируем по времени, затем по номеру поста
    all_slots.sort_by { |slot| [slot[:datetime], slot[:post_number]] }
  end

  # Получение доступных временных слотов (существующий метод)
  def self.available_slots_for_date(service_point_id, date)
    # Используем новый метод и фильтруем только доступные слоты
    all_slots_for_date(service_point_id, date).select { |slot| slot[:available] }
  end

  # Подсчет количества бронирований в указанное время
  # В слотовой архитектуре считаем только точные совпадения по времени начала
  def self.count_bookings_at_time(service_point_id, date, start_time, end_time)
    # Преобразуем время в строки для сравнения с БД
    slot_start_str = start_time.strftime('%H:%M:%S')
    
    # В слотовой архитектуре считаем бронирования с точно таким же временем начала
    Booking.where(
      service_point_id: service_point_id, 
      booking_date: date,
      start_time: slot_start_str
    ).where.not(
      status: BookingStatuses::CANCELLED_STATUSES.map(&:to_s)
    ).count
  end

  # Устаревший метод - оставляем для обратной совместимости
  def self.is_slot_occupied?(service_point_id, service_post_id, date, start_time, end_time)
    count_bookings_at_time(service_point_id, date, start_time, end_time) > 0
  end
  
  # Группировка слотов постов по времени с агрегацией доступности
  def self.available_times_for_date(service_point_id, date, min_duration_minutes = nil)
    service_point = ServicePoint.find(service_point_id)
    
    # Проверяем есть ли работающие посты в этот день (новая логика)
    return [] unless has_any_working_posts_on_date?(service_point, date)
    
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
    
    # Получаем расписание для этой даты (с учетом сезонных расписаний)
    schedule_info = get_schedule_for_date(service_point, date)
    
    total_posts = service_point.service_posts.active.select do |post|
      if post.has_custom_schedule && post.working_days.present?
        # Посты с индивидуальным расписанием не затрагиваются сезонными расписаниями
        post.working_days[day_key] == true || post.working_days[day_key.to_s] == true
      else
        # Пост работает по расписанию точки (включая сезонные расписания)
        schedule_info[:is_working]
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
  def self.check_availability_at_time(service_point_id, date, time, duration_minutes = nil, exclude_booking_id: nil, category_id: nil)
    service_point = ServicePoint.find(service_point_id)
    
    # Проверяем есть ли работающие посты в этот день (новая логика)
    if category_id.present?
      return { available: false, reason: 'Не рабочий день' } unless has_working_posts_for_category_on_date?(service_point, date, category_id)
      # Получаем рабочие часы для категории
      working_hours_info = get_working_hours_for_category(service_point, date, category_id)
    else
      return { available: false, reason: 'Не рабочий день' } unless has_any_working_posts_on_date?(service_point, date)
      # Получаем рабочие часы для всех постов
      working_hours_info = get_working_hours_for_all_posts(service_point, date)
    end
    
    # Проверяем время в рамках рабочих часов
    opening_time = Time.parse("#{date} #{working_hours_info[:opening_time].strftime('%H:%M:%S')}")
    closing_time = Time.parse("#{date} #{working_hours_info[:closing_time].strftime('%H:%M:%S')}")
    check_time = time.is_a?(String) ? Time.parse("#{date} #{time}") : time
    
    return { available: false, reason: 'Вне рабочих часов' } if check_time < opening_time || check_time >= closing_time
    
    # Если указана категория, используем слоты для конкретной категории
    available_slots = if category_id.present?
      available_slots_for_category(service_point_id, date, category_id)
    else
      available_slots_for_date(service_point_id, date)
    end
    
    # Ищем слот, который начинается в указанное время
    matching_slot = available_slots.find { |slot| slot[:start_time] == check_time.strftime('%H:%M') }
    
    # Если нет слота в указанное время, время недоступно
    unless matching_slot
      return { available: false, reason: 'Нет доступного слота в указанное время' }
    end
    
    # Определяем длительность: используем переданную или длительность слота
    actual_duration = duration_minutes || matching_slot[:duration_minutes]
    
    # Проверяем, достаточно ли длительности слота
    if actual_duration > matching_slot[:duration_minutes]
      return { 
        available: false, 
        reason: "Недостаточная длительность слота (доступно #{matching_slot[:duration_minutes]} мин, требуется #{actual_duration} мин)",
        available_duration: matching_slot[:duration_minutes],
        requested_duration: actual_duration
      }
    end
    
    # Получаем количество активных постов для данной категории или всех постов
    if category_id.present?
      # Для конкретной категории
      category_posts = service_point.service_posts.where(service_category_id: category_id, is_active: true)
      total_posts = category_posts.count
    else
      # Для всех постов
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
    end
    
    return { available: false, reason: 'Нет активных постов' } if total_posts.zero?
    
    # Определяем время окончания бронирования (используем фактическую длительность)
    end_time = check_time + actual_duration.minutes
    
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
    
    # Проверяем есть ли хотя бы один работающий пост в указанную дату
    unless has_any_working_posts_on_date?(service_point, date)
      return { 
        is_working: false,
        message: "В выбранную дату сервисная точка не работает. Пожалуйста, выберите другую дату."
      }
    end
    
    # Получаем все доступные слоты для этого дня
    available_slots = available_slots_for_date(service_point_id, date)
    
    # Получаем все возможные слоты (доступные + занятые)
    all_possible_slots = get_all_possible_slots_for_date(service_point_id, date)
    
    total_slots = all_possible_slots.count
    available_slots_count = available_slots.count
    occupied_slots_count = total_slots - available_slots_count
    
    occupancy_percentage = total_slots > 0 ? (occupied_slots_count.to_f / total_slots * 100).round(1) : 0
    
    # Получаем рабочие часы с учетом индивидуальных графиков постов
    working_hours_info = get_working_hours_for_all_posts(service_point, date)
    
    # Получаем информацию о расписании (включая сезонные)
    schedule_info = get_schedule_for_date(service_point, date)
    
    {
      is_working: true,
      opening_time: working_hours_info[:opening_time].strftime('%H:%M'),
      closing_time: working_hours_info[:closing_time].strftime('%H:%M'),
      total_posts: service_point.service_posts.active.count,
      schedule_info: {
        schedule_type: schedule_info[:schedule_type],
        schedule_name: schedule_info[:schedule_name],
        schedule_id: schedule_info[:schedule_id]
      },
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

  # Получение детальной информации о загрузке на день для конкретной категории услуг
  def self.day_occupancy_details_for_category(service_point_id, date, category_id)
    service_point = ServicePoint.find(service_point_id)
    
    # Проверяем есть ли работающие посты для данной категории в указанную дату
    unless has_working_posts_for_category_on_date?(service_point, date, category_id)
      return { 
        is_working: false, 
        message: "В выбранную дату сервисная точка не работает с услугами данной категории. Пожалуйста, выберите другую дату.",
        category_id: category_id
      }
    end

    # Получаем доступные слоты только для указанной категории
    available_slots = available_slots_for_category(service_point_id, date, category_id)
    
    # Получаем все возможные слоты для категории (доступные + занятые)
    all_possible_slots = get_all_possible_slots_for_category(service_point_id, date, category_id)
    
    # Правильный подсчет: считаем фактические бронирования
    actual_bookings_count = Booking.joins(:service_category)
      .where(
        service_point_id: service_point_id,
        booking_date: date,
        service_category_id: category_id
      )
      .where.not(
        status_id: BookingStatus.canceled_statuses
      ).count
    
    total_slots = all_possible_slots.count
    available_slots_count = available_slots.count
    occupied_slots_count = actual_bookings_count  # Используем фактическое количество бронирований
    
    occupancy_percentage = total_slots > 0 ? (occupied_slots_count.to_f / total_slots * 100).round(1) : 0
    
    # Получаем количество постов для данной категории
    category_posts_count = service_point.posts_count_for_category(category_id)
    
    # Получаем время работы (может быть из общего расписания или индивидуального)
    working_hours_info = get_working_hours_for_category(service_point, date, category_id)
    
    # Получаем информацию о расписании (включая сезонные)
    schedule_info = get_schedule_for_date(service_point, date)
    
    {
      is_working: true,
      opening_time: working_hours_info[:opening_time].strftime('%H:%M'),
      closing_time: working_hours_info[:closing_time].strftime('%H:%M'),
      total_posts: category_posts_count,
      category_id: category_id,
      schedule_info: {
        schedule_type: schedule_info[:schedule_type],
        schedule_name: schedule_info[:schedule_name],
        schedule_id: schedule_info[:schedule_id]
      },
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
    
    # Проверяем есть ли хотя бы один работающий пост в указанную дату
    # (не полагаемся только на общее расписание, учитываем индивидуальные графики)
    unless has_any_working_posts_on_date?(service_point, date)
      return []
    end
    
    # Определяем день недели
    day_key = case date.wday
    when 0 then 'sunday'
    when 1 then 'monday'
    when 2 then 'tuesday'
    when 3 then 'wednesday'
    when 4 then 'thursday'
    when 5 then 'friday'
    when 6 then 'saturday'
    end
    
    # Получаем расписание для этой даты (с учетом сезонных расписаний)
    schedule_info = get_schedule_for_date(service_point, date)
    
    # Получаем все активные посты, работающие в этот день
    working_posts = service_point.service_posts.active.select do |post|
      if post.has_custom_schedule?
        # Пост имеет индивидуальный график (не затрагивается сезонными расписаниями)
        post.working_on_day?(day_key)
      else
        # Пост работает по общему расписанию сервисной точки (включая сезонные расписания)
        schedule_info[:is_working]
      end
    end
    
    return [] if working_posts.empty?
    
    all_slots = []
    
    # Генерируем слоты для каждого работающего поста
    working_posts.each do |service_post|
      # Определяем время работы поста
      if service_post.has_custom_schedule?
        # Пост с индивидуальным расписанием
        start_time_str = service_post.start_time_for_day(day_key)
        end_time_str = service_post.end_time_for_day(day_key)
      else
        # Пост работает по общему расписанию (включая сезонные расписания)
        if schedule_info[:opening_time] && schedule_info[:closing_time]
          start_time_str = schedule_info[:opening_time].strftime('%H:%M')
          end_time_str = schedule_info[:closing_time].strftime('%H:%M')
        else
          # Fallback на время поста
          start_time_str = service_post.start_time_for_day(day_key)
          end_time_str = service_post.end_time_for_day(day_key)
        end
      end
      
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

  # Получение всех возможных слотов для дня и категории (включая занятые)
  def self.get_all_possible_slots_for_category(service_point_id, date, category_id)
    service_point = ServicePoint.find(service_point_id)
    
    # Проверяем есть ли работающие посты для данной категории в указанную дату
    unless has_working_posts_for_category_on_date?(service_point, date, category_id)
      return []
    end
    
    # Получаем посты только для указанной категории
    category_posts = service_point.service_posts.where(service_category_id: category_id, is_active: true)
    return [] if category_posts.empty?
    
    # Определяем день недели
    day_key = case date.wday
    when 0 then 'sunday'
    when 1 then 'monday'
    when 2 then 'tuesday'
    when 3 then 'wednesday'
    when 4 then 'thursday'
    when 5 then 'friday'
    when 6 then 'saturday'
    end
    
    all_slots = []
    
    # Получаем расписание для этой даты (с учетом сезонных расписаний)
    schedule_info = get_schedule_for_date(service_point, date)
    
    # Проходим только по постам указанной категории
    category_posts.ordered_by_post_number.each do |service_post|
      # Проверяем, работает ли пост в этот день
      works_on_day = if service_post.has_custom_schedule?
        # Пост имеет индивидуальный график (не затрагивается сезонными расписаниями)
        service_post.working_on_day?(day_key)
      else
        # Пост работает по общему расписанию сервисной точки (включая сезонные расписания)
        schedule_info[:is_working]
      end
      
      next unless works_on_day
      
      # Определяем время работы поста
      if service_post.has_custom_schedule?
        # Пост с индивидуальным расписанием
        start_time_str = service_post.start_time_for_day(day_key)
        end_time_str = service_post.end_time_for_day(day_key)
      else
        # Пост работает по общему расписанию (включая сезонные расписания)
        if schedule_info[:opening_time] && schedule_info[:closing_time]
          start_time_str = schedule_info[:opening_time].strftime('%H:%M')
          end_time_str = schedule_info[:closing_time].strftime('%H:%M')
        else
          # Fallback на время поста
          start_time_str = service_post.start_time_for_day(day_key)
          end_time_str = service_post.end_time_for_day(day_key)
        end
      end
      
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
          category_id: category_id,
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

  # Проверка доступности времени с учетом категории услуг
  def self.check_availability_with_category(service_point_id, date, start_time, duration, category_id)
    begin
      service_point = ServicePoint.find(service_point_id)
    rescue ActiveRecord::RecordNotFound
      return {
        available: false,
        reason: 'Сервисная точка не найдена',
        available_posts_count: 0,
        total_posts_count: 0
      }
    end
    
    # Получаем посты только для указанной категории
    available_posts = service_point.posts_for_category(category_id)
    
    return {
      available: false,
      reason: 'Нет активных постов для данной категории услуг',
      available_posts_count: 0,
      total_posts_count: 0
    } if available_posts.empty?
    
    # Парсим время
    datetime = DateTime.parse("#{date} #{start_time}")
    end_datetime = datetime + duration.minutes
    
    available_posts_count = 0
    
    available_posts.each do |post|
      # Проверяем доступность поста в указанное время
      next unless post.available_at_time?(datetime)
      
      # Проверяем пересечения с существующими бронированиями
      overlapping_bookings = Booking.where(service_point: service_point)
                                    .where(booking_date: date)
                                    .where('start_time < ? AND end_time > ?', 
                                           end_datetime.strftime('%H:%M'), 
                                           start_time)
                                    .where.not(status_id: BookingStatus.canceled_statuses)
                                    .count
      
      # Если нет пересечений, пост доступен
      available_posts_count += 1 if overlapping_bookings == 0
    end
    
    {
      available: available_posts_count > 0,
      reason: available_posts_count > 0 ? nil : 'Все посты данной категории заняты в указанное время',
      available_posts_count: available_posts_count,
      total_posts_count: available_posts.count,
      category_id: category_id
    }
  end

  # Получение доступных временных слотов для конкретной категории
  def self.available_slots_for_category(service_point_id, date, category_id)
    service_point = ServicePoint.find(service_point_id)
    
    # Преобразуем строку даты в объект Date
    date = Date.parse(date) if date.is_a?(String)
    
    # Получаем посты только для указанной категории
    category_posts = service_point.service_posts.where(service_category_id: category_id, is_active: true)
    return [] if category_posts.empty?
    
    # Проверяем есть ли работающие посты для данной категории в этот день (новая логика)
    return [] unless has_working_posts_for_category_on_date?(service_point, date, category_id)
    
    # Определяем день недели  
    day_key = case date.wday
    when 0 then 'sunday'
    when 1 then 'monday'
    when 2 then 'tuesday'
    when 3 then 'wednesday'
    when 4 then 'thursday'
    when 5 then 'friday'
    when 6 then 'saturday'
    end
    
    # Получаем расписание для этой даты (с учетом сезонных расписаний)
    schedule_info = get_schedule_for_date(service_point, date)
    
    # Фильтруем посты, работающие в этот день
    working_posts = category_posts.select do |post|
      if post.has_custom_schedule?
        # Пост имеет индивидуальный график (не затрагивается сезонными расписаниями)
        post.working_on_day?(day_key)
      else
        # Пост работает по общему расписанию сервисной точки (включая сезонные расписания)
        schedule_info[:is_working]
      end
    end
    
    return [] if working_posts.empty?
    
    # Генерируем все возможные временные слоты и группируем по времени
    time_slots = {}
    
    working_posts.each do |post|
      # Определяем время работы для этого поста
      if post.has_custom_schedule?
        # Пост с индивидуальным расписанием
        start_time_str = post.start_time_for_day(day_key)
        end_time_str = post.end_time_for_day(day_key)
      else
        # Пост работает по общему расписанию (включая сезонные расписания)
        if schedule_info[:opening_time] && schedule_info[:closing_time]
          start_time_str = schedule_info[:opening_time].strftime('%H:%M')
          end_time_str = schedule_info[:closing_time].strftime('%H:%M')
        else
          # Fallback на время поста
          start_time_str = post.start_time_for_day(day_key)
          end_time_str = post.end_time_for_day(day_key)
        end
      end
      
      slot_duration = post.slot_duration
      
      start_time = Time.parse("#{date} #{start_time_str}")
      end_time = Time.parse("#{date} #{end_time_str}")
      
      current_time = start_time
      
      while current_time + slot_duration.minutes <= end_time
        time_key = current_time.strftime('%H:%M')
        
        # Инициализируем слот если его еще нет
        unless time_slots[time_key]
          time_slots[time_key] = {
            time: time_key,
            datetime: current_time,
            total_posts: 0,
            posts: []
          }
        end
        
        # Добавляем пост к этому времени
        time_slots[time_key][:total_posts] += 1
        time_slots[time_key][:posts] << {
          service_post_id: post.id,
          post_number: post.post_number,
          post_name: post.name || "Пост #{post.post_number}",
          duration_minutes: slot_duration
        }
        
        current_time += slot_duration.minutes
      end
    end
    
    # Теперь для каждого временного слота проверяем доступность
    available_slots = []
    
    time_slots.each do |time_key, slot_data|
      # Подсчитываем количество бронирований на это время
      bookings_count = Booking.joins(:service_category)
        .where(
          service_point_id: service_point_id,
          booking_date: date,
          start_time: "#{time_key}:00",
          service_category_id: category_id
        )
        .where.not(
          status_id: BookingStatus.canceled_statuses
        ).count
      
      # Вычисляем количество доступных постов
      available_posts_count = slot_data[:total_posts] - bookings_count
      
      # Если есть хотя бы один доступный пост, добавляем слот
      if available_posts_count > 0
        # Берем данные первого поста для duration_minutes (они одинаковые для одного времени)
        first_post = slot_data[:posts].first
        slot_end_time = slot_data[:datetime] + first_post[:duration_minutes].minutes
        
        available_slots << {
          service_post_id: first_post[:service_post_id],
          post_number: first_post[:post_number],
          post_name: first_post[:post_name],
          category_id: category_id,
          category_name: working_posts.first.category_name,
          start_time: time_key,
          end_time: slot_end_time.strftime('%H:%M'),
          duration_minutes: first_post[:duration_minutes],
          datetime: slot_data[:datetime],
          available_posts: available_posts_count,
          total_posts: slot_data[:total_posts],
          bookings_count: bookings_count
        }
      end
    end
    
    # Сортируем по времени
    available_slots.sort_by { |slot| slot[:datetime] }
  end

  private

  # Получение рабочих часов для даты с учетом working_hours
  def self.get_schedule_for_date(service_point, date)
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
    
    # Сначала проверяем сезонное расписание
    seasonal_schedule = SeasonalSchedule.find_active_for_date(service_point.id, date)
    
    if seasonal_schedule
      Rails.logger.info "DynamicAvailabilityService: Найдено сезонное расписание '#{seasonal_schedule.name}' для точки #{service_point.id} на дату #{date}"
      
      day_schedule = seasonal_schedule.schedule_for_day(day_key)
      return { is_working: false, schedule_type: 'seasonal', schedule_name: seasonal_schedule.name } unless day_schedule.present?
      
      is_working = day_schedule['is_working_day'] == true || day_schedule['is_working_day'] == 'true'
      return { is_working: false, schedule_type: 'seasonal', schedule_name: seasonal_schedule.name } unless is_working
      
      begin
        opening_time = Time.parse("#{date} #{day_schedule['start']}:00")
        closing_time = Time.parse("#{date} #{day_schedule['end']}:00")
        
        return {
          is_working: true,
          opening_time: opening_time,
          closing_time: closing_time,
          schedule_type: 'seasonal',
          schedule_name: seasonal_schedule.name,
          schedule_id: seasonal_schedule.id
        }
      rescue => e
        Rails.logger.error "DynamicAvailabilityService: Ошибка парсинга времени из сезонного расписания #{seasonal_schedule.id}, день #{day_key}: #{e.message}"
        return { is_working: false, schedule_type: 'seasonal', schedule_name: seasonal_schedule.name }
      end
    end
    
    # Если нет сезонного расписания, используем обычное расписание
    return { is_working: false, schedule_type: 'regular' } unless service_point.working_hours.present?
    
    day_schedule = service_point.working_hours[day_key]
    return { is_working: false, schedule_type: 'regular' } unless day_schedule.present?
    
    is_working = day_schedule['is_working_day'] == true || day_schedule['is_working_day'] == 'true'
    return { is_working: false, schedule_type: 'regular' } unless is_working
    
    begin
      opening_time = Time.parse("#{date} #{day_schedule['start']}:00")
      closing_time = Time.parse("#{date} #{day_schedule['end']}:00")
      
      {
        is_working: true,
        opening_time: opening_time,
        closing_time: closing_time,
        schedule_type: 'regular'
      }
    rescue => e
      Rails.logger.error "DynamicAvailabilityService: Ошибка парсинга времени для точки #{service_point.id}, день #{day_key}: #{e.message}"
      { is_working: false, schedule_type: 'regular' }
    end
  end

  # Подсчет занятых постов в конкретное время
  # В слотовой архитектуре считаем только по точному времени начала
  def self.count_occupied_posts_at_time(service_point_id, date, time, exclude_booking_id: nil)
    # Преобразуем время в строковый формат для сравнения с полями времени в БД
    time_string = time.strftime('%H:%M:%S')
    
    # Считаем бронирования с точно таким же временем начала
    query = Booking.where(
      service_point_id: service_point_id,
      booking_date: date,
      start_time: time_string
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
    busy_intervals = intervals.count { |i| i[:occupancy_rate] == 0 }
    avg_occupancy = intervals.sum { |i| i[:occupancy_rate] } / total_intervals
    
    {
      total_intervals: total_intervals,
      busy_intervals: busy_intervals,
      free_intervals: total_intervals - busy_intervals,
      average_occupancy_rate: avg_occupancy.round(1),
      peak_occupancy_rate: intervals.map { |i| i[:occupancy_rate] }.max
    }
  end

  # Проверяет, есть ли работающие посты для конкретной категории в указанную дату
  def self.has_working_posts_for_category_on_date?(service_point, date, category_id)
    # Определяем день недели
    day_key = case date.wday
    when 0 then 'sunday'
    when 1 then 'monday'
    when 2 then 'tuesday'
    when 3 then 'wednesday'
    when 4 then 'thursday'
    when 5 then 'friday'
    when 6 then 'saturday'
    end
    
    # Получаем расписание для этой даты (с учетом сезонных расписаний)
    schedule_info = get_schedule_for_date(service_point, date)
    
    # Получаем посты для указанной категории
    category_posts = service_point.service_posts.where(service_category_id: category_id, is_active: true)
    return false if category_posts.empty?
    
    # Проверяем есть ли хотя бы один пост, работающий в этот день
    category_posts.any? do |post|
      if post.has_custom_schedule?
        # Пост имеет индивидуальный график (не затрагивается сезонными расписаниями)
        post.working_on_day?(day_key)
      else
        # Пост работает по общему расписанию сервисной точки (включая сезонные расписания)
        schedule_info[:is_working]
      end
    end
  end
  
  # Получает рабочие часы для категории (учитывает индивидуальные графики постов)
  def self.get_working_hours_for_category(service_point, date, category_id)
    day_key = case date.wday
    when 0 then 'sunday'
    when 1 then 'monday'
    when 2 then 'tuesday'
    when 3 then 'wednesday'
    when 4 then 'thursday'
    when 5 then 'friday'
    when 6 then 'saturday'
    end
    
    # Получаем расписание для этой даты (с учетом сезонных расписаний)
    schedule_info = get_schedule_for_date(service_point, date)
    
    # Получаем работающие посты для данной категории
    category_posts = service_point.service_posts.where(service_category_id: category_id, is_active: true)
    working_posts = category_posts.select do |post|
      if post.has_custom_schedule?
        post.working_on_day?(day_key)
      else
        schedule_info[:is_working]
      end
    end
    
    # Находим самое раннее время открытия и самое позднее время закрытия
    opening_times = []
    closing_times = []
    
    working_posts.each do |post|
      if post.has_custom_schedule?
        # Пост с индивидуальным расписанием
        opening_times << post.start_time_for_day(day_key)
        closing_times << post.end_time_for_day(day_key)
      else
        # Пост работает по общему расписанию (включая сезонные расписания)
        if schedule_info[:opening_time] && schedule_info[:closing_time]
          opening_times << schedule_info[:opening_time].strftime('%H:%M')
          closing_times << schedule_info[:closing_time].strftime('%H:%M')
        end
      end
    end
    
    earliest_opening = opening_times.min || '09:00'
    latest_closing = closing_times.max || '18:00'
    
    {
      opening_time: Time.parse("#{date} #{earliest_opening}:00"),
      closing_time: Time.parse("#{date} #{latest_closing}:00")
    }
  end

  # Проверяет, есть ли хотя бы один работающий пост в указанную дату (любой категории)
  def self.has_any_working_posts_on_date?(service_point, date)
    # Определяем день недели
    day_key = case date.wday
    when 0 then 'sunday'
    when 1 then 'monday'
    when 2 then 'tuesday'
    when 3 then 'wednesday'
    when 4 then 'thursday'
    when 5 then 'friday'
    when 6 then 'saturday'
    end
    
    # Получаем расписание для этой даты (с учетом сезонных расписаний)
    schedule_info = get_schedule_for_date(service_point, date)
    
    # Получаем все активные посты
    all_posts = service_point.service_posts.where(is_active: true)
    return false if all_posts.empty?
    
    # Проверяем есть ли хотя бы один пост, работающий в этот день
    all_posts.any? do |post|
      if post.has_custom_schedule?
        # Пост имеет индивидуальный график (не затрагивается сезонными расписаниями)
        post.working_on_day?(day_key)
      else
        # Пост работает по общему расписанию сервисной точки (включая сезонные расписания)
        schedule_info[:is_working]
      end
    end
  end

  # Получает рабочие часы с учетом всех работающих постов (любых категорий)
  def self.get_working_hours_for_all_posts(service_point, date)
    day_key = case date.wday
    when 0 then 'sunday'
    when 1 then 'monday'
    when 2 then 'tuesday'
    when 3 then 'wednesday'
    when 4 then 'thursday'
    when 5 then 'friday'
    when 6 then 'saturday'
    end
    
    # Получаем расписание для этой даты (с учетом сезонных расписаний)
    schedule_info = get_schedule_for_date(service_point, date)
    
    # Получаем все работающие посты
    all_posts = service_point.service_posts.where(is_active: true)
    working_posts = all_posts.select do |post|
      if post.has_custom_schedule?
        post.working_on_day?(day_key)
      else
        schedule_info[:is_working]
      end
    end
    
    # Находим самое раннее время открытия и самое позднее время закрытия
    opening_times = []
    closing_times = []
    
    working_posts.each do |post|
      if post.has_custom_schedule?
        # Пост с индивидуальным расписанием
        opening_times << post.start_time_for_day(day_key)
        closing_times << post.end_time_for_day(day_key)
      else
        # Пост работает по общему расписанию (включая сезонные расписания)
        if schedule_info[:opening_time] && schedule_info[:closing_time]
          opening_times << schedule_info[:opening_time].strftime('%H:%M')
          closing_times << schedule_info[:closing_time].strftime('%H:%M')
        end
      end
    end
    
    earliest_opening = opening_times.min || '09:00'
    latest_closing = closing_times.max || '18:00'
    
    {
      opening_time: Time.parse("#{date} #{earliest_opening}:00"),
      closing_time: Time.parse("#{date} #{latest_closing}:00")
    }
  end
end 