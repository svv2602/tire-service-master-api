class ScheduleManager
  # Генерирует слоты расписания на указанную дату для указанной сервисной точки
  def self.generate_slots_for_date(service_point_id, date)
    service_point = ServicePoint.find(service_point_id)
    
    # Проверяем наличие активных постов
    active_posts = service_point.service_posts.active
    if active_posts.empty?
      Rails.logger.warn "ScheduleManager: Нет активных постов для точки обслуживания #{service_point_id}"
      delete_unused_slots(service_point_id, date)
      return
    end
    
    # Преобразуем wday (0-воскресенье, 1-6 пн-сб) в sort_order (1-7 пн-вс)
    sort_order = date.wday == 0 ? 7 : date.wday
    weekday = Weekday.find_by(sort_order: sort_order)
    
    # Проверяем, если на указанную дату есть исключение из расписания
    exception = ScheduleException.find_by(service_point_id: service_point_id, exception_date: date)
    
    if exception
      if exception.is_working_day
        # Для рабочего дня исключения используем особое расписание
        generate_slots_from_exception(service_point, date, exception)
      else
        # Для нерабочего дня просто удаляем все существующие неиспользуемые слоты
        delete_unused_slots(service_point_id, date)
      end
      return
    end
    
    # Находим шаблон расписания для указанного дня недели
    template = ScheduleTemplate.find_by(service_point_id: service_point_id, weekday_id: weekday.id)
    
    # Если шаблона нет или день нерабочий, удаляем все неиспользуемые слоты и выходим
    if template.nil? || !template.is_working_day
      delete_unused_slots(service_point_id, date)
      return
    end
    
    # Генерируем слоты на основе шаблона с учетом индивидуальных постов
    generate_slots_from_template_with_posts(service_point, date, template)
  end
  
  # Генерирует слоты расписания на указанный период для указанной сервисной точки
  def self.generate_slots_for_period(service_point_id, start_date, end_date)
    (start_date..end_date).each do |date|
      generate_slots_for_date(service_point_id, date)
    end
  end
  
  # Генерирует слоты для всех сервисных точек на указанную дату
  def self.generate_slots_for_all_service_points(date)
    ServicePoint.active.each do |service_point|
      generate_slots_for_date(service_point.id, date)
    end
  end
  
  # Удаляет все неиспользуемые слоты на указанную дату для указанной сервисной точки
  def self.delete_unused_slots(service_point_id, date)
    # Получаем все слоты для данной точки и даты
    slots = ScheduleSlot.where(service_point_id: service_point_id, slot_date: date)
    
    slots_to_delete = []
    
    slots.each do |slot|
      # Проверяем, есть ли бронирования в это время для этой точки
      has_bookings = Booking.where(
        service_point_id: service_point_id,
        booking_date: date
      ).where(
        "(start_time < ? AND end_time > ?) OR (start_time >= ? AND start_time < ?)",
        slot.end_time, slot.start_time, slot.start_time, slot.end_time
      ).exists?
      
      # Если нет бронирований, слот можно удалить
      unless has_bookings
        slots_to_delete << slot
      end
    end
    
    # Удаляем неиспользуемые слоты
    ScheduleSlot.where(id: slots_to_delete.map(&:id)).destroy_all if slots_to_delete.any?
  end
  
  private
  
  # Генерирует слоты на основе шаблона расписания с учетом индивидуальных постов
  def self.generate_slots_from_template_with_posts(service_point, date, template)
    # Сначала удаляем все неиспользуемые слоты для этой даты
    delete_unused_slots(service_point.id, date)
    
    # Определяем день недели для проверки индивидуальных расписаний
    day_key = date.strftime('%A').downcase # monday, tuesday, etc.
    
    # Получаем активные посты
    active_posts = service_point.service_posts.active.ordered_by_post_number
    
    # Для каждого поста проверяем, работает ли он в этот день
    active_posts.each do |service_post|
      # Проверяем, работает ли пост в этот день недели
      next unless service_post.working_on_day?(day_key)
      
      # Определяем время работы поста
      post_start_time = parse_time_for_post(service_post, day_key, 'start', template.opening_time)
      post_end_time = parse_time_for_post(service_post, day_key, 'end', template.closing_time)
      
      # Генерируем слоты для этого поста в его рабочие часы
      generate_slots_for_post(service_point, date, post_start_time, post_end_time, service_post)
    end
  end
  
  # Определяет время начала или окончания работы поста
  def self.parse_time_for_post(service_post, day_key, time_type, default_time)
    if service_post.has_custom_schedule? && service_post.custom_hours.present?
      time_string = service_post.custom_hours[time_type]
      return Time.parse("2024-01-01 #{time_string}").strftime('%H:%M:%S') if time_string.present?
    end
    
    # Если нет индивидуального времени, используем время точки обслуживания
    if service_post.service_point.working_hours.present?
      day_hours = service_post.service_point.working_hours[day_key]
      if day_hours.is_a?(Hash) && day_hours[time_type].present?
        return day_hours[time_type]
      end
    end
    
    # Если ничего не найдено, используем время по умолчанию из шаблона
    default_time.strftime('%H:%M:%S')
  end
  
  # Генерирует слоты для конкретного поста с его индивидуальной длительностью
  def self.generate_slots_for_post(service_point, date, start_time_str, end_time_str, service_post)
    slot_duration = service_post.slot_duration
    
    # Если переданы объекты Time, преобразуем их в строки времени
    if start_time_str.is_a?(Time)
      start_time_str = start_time_str.strftime('%H:%M:%S')
    end
    if end_time_str.is_a?(Time)
      end_time_str = end_time_str.strftime('%H:%M:%S')
    end
    
    # Парсим время из строки в объекты Time для данной даты
    start_time = Time.parse("#{date} #{start_time_str}")
    end_time = Time.parse("#{date} #{end_time_str}")
    
    current_time = start_time
    
    while current_time + slot_duration.minutes <= end_time
      slot_end_time = current_time + slot_duration.minutes
      
      # Проверяем, нет ли уже такого слота
      slot = ScheduleSlot.find_by(
        service_point_id: service_point.id,
        service_post_id: service_post.id,
        slot_date: date,
        start_time: current_time.strftime('%H:%M:%S'),
        end_time: slot_end_time.strftime('%H:%M:%S')
      )
      
      # Если слота нет, создаем его
      unless slot
        begin
          ScheduleSlot.create!(
            service_point_id: service_point.id,
            service_post_id: service_post.id,
            slot_date: date,
            start_time: current_time.strftime('%H:%M:%S'),
            end_time: slot_end_time.strftime('%H:%M:%S'),
            post_number: service_post.post_number,
            is_available: true
          )
        rescue ActiveRecord::RecordNotUnique
          # Игнорируем дублирующиеся слоты
          Rails.logger.debug "Слот уже существует для поста #{service_post.post_number} в #{current_time}"
        end
      end
      
      # Переходим к следующему временному слоту для этого поста
      current_time = slot_end_time
    end
  end
  
  # Генерирует слоты на основе исключения из расписания с учетом индивидуальных постов
  def self.generate_slots_from_exception(service_point, date, exception)
    # Сначала удаляем все неиспользуемые слоты для этой даты
    delete_unused_slots(service_point.id, date)
    
    # Определяем день недели для проверки индивидуальных расписаний
    day_key = date.strftime('%A').downcase # monday, tuesday, etc.
    
    # Получаем активные посты
    active_posts = service_point.service_posts.active.ordered_by_post_number
    
    # Для каждого поста проверяем, работает ли он в этот день
    active_posts.each do |service_post|
      # Проверяем, работает ли пост в этот день недели
      next unless service_post.working_on_day?(day_key)
      
      # Определяем время работы поста для исключения
      post_start_time = parse_time_for_post_exception(service_post, day_key, 'start', exception.start_time)
      post_end_time = parse_time_for_post_exception(service_post, day_key, 'end', exception.end_time)
      
      # Генерируем слоты для этого поста в его рабочие часы
      generate_slots_for_post(service_point, date, post_start_time, post_end_time, service_post)
    end
  end
  
  # Определяет время для исключения с учетом индивидуального расписания поста
  def self.parse_time_for_post_exception(service_post, day_key, time_type, exception_time)
    if service_post.has_custom_schedule? && service_post.custom_hours.present?
      time_string = service_post.custom_hours[time_type]
      return time_string if time_string.present?
    end
    
    # Если нет индивидуального времени, используем время из исключения
    exception_time.strftime('%H:%M:%S')
  end
  
  # Проверяет, доступен ли указанный временной интервал для бронирования
  def self.is_time_available?(service_point_id, date, start_time, end_time)
    # Проверяем, есть ли слот в указанное время
    slot = ScheduleSlot.where(
      service_point_id: service_point_id,
      slot_date: date,
      start_time: start_time,
      end_time: end_time,
      is_available: true
    ).first
    
    return false unless slot
    
    # Проверяем, нет ли бронирований в это время
    has_bookings = Booking.where(
      service_point_id: service_point_id,
      booking_date: date
    ).where(
      "(start_time < ? AND end_time > ?) OR (start_time >= ? AND start_time < ?)",
      end_time, start_time, start_time, end_time
    ).exists?
    
    return !has_bookings
  end
  
  # Находит ближайшее свободное время для бронирования
  def self.find_next_available_slot(service_point_id, date, preferred_time = nil)
    service_point = ServicePoint.find(service_point_id)
    
    # Если предпочтительное время не указано, берем текущее время или начало дня
    preferred_time ||= Time.current.strftime("%H:%M:%S")
    
    # Ищем свободный слот на указанную дату
    slots = ScheduleSlot.where(
      service_point_id: service_point_id,
      slot_date: date,
      is_available: true
    ).where("start_time >= ?", preferred_time)
    .order(start_time: :asc)
    
    # Проверяем каждый слот на наличие бронирований
    slots.each do |slot|
      has_bookings = Booking.where(
        service_point_id: service_point_id,
        booking_date: date
      ).where(
        "(start_time < ? AND end_time > ?) OR (start_time >= ? AND start_time < ?)",
        slot.end_time, slot.start_time, slot.start_time, slot.end_time
      ).exists?
      
      # Если нет бронирований, возвращаем этот слот
      return slot unless has_bookings
    end
    
    # Если на указанную дату нет свободных слотов, ищем на следующие даты
    next_date = date + 1.day
    next_date_limit = date + 30.days # ограничиваем поиск 30 днями вперед
    
    while next_date <= next_date_limit
      # Генерируем слоты для следующей даты, если их еще нет
      generate_slots_for_date(service_point_id, next_date)
      
      # Ищем свободный слот на следующую дату
      slots = ScheduleSlot.where(
        service_point_id: service_point_id,
        slot_date: next_date,
        is_available: true
      ).order(start_time: :asc)
      
      # Проверяем каждый слот на наличие бронирований
      slots.each do |slot|
        has_bookings = Booking.where(
          service_point_id: service_point_id,
          booking_date: next_date
        ).where(
          "(start_time < ? AND end_time > ?) OR (start_time >= ? AND start_time < ?)",
          slot.end_time, slot.start_time, slot.start_time, slot.end_time
        ).exists?
        
        # Если нет бронирований, возвращаем этот слот
        return slot unless has_bookings
      end
      
      # Переходим к следующей дате
      next_date += 1.day
    end
    
    # Если не нашли свободных слотов, возвращаем nil
    nil
  end
end 