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
    
    # Определяем день недели
    day_key = date.strftime('%A').downcase # monday, tuesday, etc.
    
    # Проверяем рабочие часы сервисной точки
    working_hours = service_point.working_hours
    if working_hours.blank? || working_hours[day_key].blank?
      delete_unused_slots(service_point_id, date)
      return
    end
    
    day_schedule = working_hours[day_key]
    is_working_day = day_schedule['is_working_day'] == 'true' || day_schedule['is_working_day'] == true
    
    # Если день нерабочий, удаляем слоты
    unless is_working_day
      delete_unused_slots(service_point_id, date)
      return
    end
    
    # Генерируем слоты для каждого активного поста
    generate_slots_from_working_hours(service_point, date, day_key)
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
  
  # Генерирует слоты на основе working_hours с учетом индивидуальных постов
  def self.generate_slots_from_working_hours(service_point, date, day_key)
    # Сначала удаляем все неиспользуемые слоты для этой даты
    delete_unused_slots(service_point.id, date)
    
    # Получаем активные посты
    active_posts = service_point.service_posts.active.ordered_by_post_number
    
    # Для каждого поста проверяем, работает ли он в этот день
    active_posts.each do |service_post|
      # Проверяем, работает ли пост в этот день недели
      next unless service_post.working_on_day?(day_key)
      
      # Определяем время работы поста
      post_start_time = service_post.start_time_for_day(day_key)
      post_end_time = service_post.end_time_for_day(day_key)
      
      # Генерируем слоты для этого поста в его рабочие часы
      generate_slots_for_post(service_point, date, post_start_time, post_end_time, service_post)
    end
  end
  
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

  # ==================== TEMPORARY RESERVATION METHODS ====================

  # Temporarily reserve a slot for a session
  # @param session_id [String] unique session identifier
  # @param slot_id [Integer] slot to reserve
  # @param timeout_minutes [Integer] reservation timeout (default 10 min)
  # @return [Hash] result with success status and slot info
  def self.reserve_slot_temporarily(session_id, slot_id, timeout_minutes: 10)
    slot = ScheduleSlot.find_by(id: slot_id)

    return { success: false, error: 'slot_not_found' } unless slot
    return { success: false, error: 'slot_not_available' } unless slot.can_be_reserved?

    if slot.reserve!(session_id, timeout_minutes: timeout_minutes)
      {
        success: true,
        slot: slot,
        reserved_until: slot.reserved_until,
        remaining_seconds: slot.reservation_remaining_seconds
      }
    else
      { success: false, error: 'reservation_failed' }
    end
  end

  # Reserve multiple consecutive slots for a service that requires more time
  # @param session_id [String] unique session identifier
  # @param slot_ids [Array<Integer>] slots to reserve
  # @param timeout_minutes [Integer] reservation timeout
  # @return [Hash] result with success status
  def self.reserve_multiple_slots(session_id, slot_ids, timeout_minutes: 10)
    slots = ScheduleSlot.where(id: slot_ids).order(:start_time)

    return { success: false, error: 'slots_not_found' } if slots.count != slot_ids.length

    # Check all slots are available before reserving
    slots.each do |slot|
      unless slot.can_be_reserved?
        return { success: false, error: 'some_slots_not_available', unavailable_slot_id: slot.id }
      end
    end

    # Check slots are consecutive and on same post
    unless slots_are_consecutive?(slots)
      return { success: false, error: 'slots_not_consecutive' }
    end

    # Reserve all slots in a transaction
    reserved_slots = []
    ScheduleSlot.transaction do
      slots.each do |slot|
        unless slot.reserve!(session_id, timeout_minutes: timeout_minutes)
          raise ActiveRecord::Rollback
        end
        reserved_slots << slot
      end
    end

    if reserved_slots.length == slots.length
      {
        success: true,
        slots: reserved_slots,
        total_duration: calculate_total_duration(reserved_slots),
        reserved_until: reserved_slots.first.reserved_until,
        remaining_seconds: reserved_slots.first.reservation_remaining_seconds
      }
    else
      # Rollback happened, release any reserved slots
      reserved_slots.each { |s| s.release!(session_id) }
      { success: false, error: 'reservation_failed' }
    end
  end

  # Release a reserved slot
  # @param session_id [String] session that made the reservation
  # @param slot_id [Integer] slot to release
  # @return [Hash] result with success status
  def self.release_slot(session_id, slot_id)
    slot = ScheduleSlot.find_by(id: slot_id)

    return { success: false, error: 'slot_not_found' } unless slot

    if slot.release!(session_id)
      { success: true }
    else
      { success: false, error: 'release_failed' }
    end
  end

  # Release all slots reserved by a session
  # @param session_id [String] session identifier
  # @return [Hash] result with count of released slots
  def self.release_all_slots_for_session(session_id)
    slots = ScheduleSlot.reserved_by_session(session_id)
    released_count = 0

    slots.each do |slot|
      released_count += 1 if slot.release!(session_id)
    end

    { success: true, released_count: released_count }
  end

  # Get all slots reserved by a session
  # @param session_id [String] session identifier
  # @return [ActiveRecord::Relation] slots
  def self.get_slots_for_session(session_id)
    ScheduleSlot.reserved_by_session(session_id).order(:slot_date, :start_time)
  end

  # Find available slots for a given duration (considering service durations)
  # @param service_point_id [Integer] service point to search
  # @param date [Date] date to search
  # @param duration_minutes [Integer] required duration
  # @param options [Hash] additional options (start_time, end_time, post_id)
  # @return [Array<Hash>] available time windows with slots
  def self.find_available_slots_for_duration(service_point_id, date, duration_minutes, options = {})
    service_point = ServicePoint.find_by(id: service_point_id)
    return [] unless service_point

    # Build base query
    query = ScheduleSlot.where(
      service_point_id: service_point_id,
      slot_date: date,
      is_available: true
    ).not_reserved

    # Filter by post if specified
    query = query.for_service_post(options[:post_id]) if options[:post_id].present?

    # Filter by time range if specified
    if options[:start_time].present?
      query = query.where('start_time >= ?', options[:start_time])
    end

    if options[:end_time].present?
      query = query.where('end_time <= ?', options[:end_time])
    end

    slots = query.order(:service_post_id, :start_time)

    # Group slots by post
    slots_by_post = slots.group_by(&:service_post_id)

    available_windows = []

    slots_by_post.each do |post_id, post_slots|
      # Find consecutive slot groups that can accommodate the duration
      windows = find_consecutive_windows(post_slots, duration_minutes)

      windows.each do |window|
        # Check for booking conflicts
        has_conflict = Booking.where(
          service_point_id: service_point_id,
          booking_date: date
        ).where(
          "(start_time < ? AND end_time > ?)",
          window[:end_time], window[:start_time]
        ).exists?

        next if has_conflict

        available_windows << {
          post_id: post_id,
          post_number: window[:slots].first.post_number,
          start_time: window[:start_time],
          end_time: window[:end_time],
          duration_minutes: window[:duration],
          slot_ids: window[:slots].map(&:id),
          slots_count: window[:slots].count
        }
      end
    end

    available_windows.sort_by { |w| [w[:start_time].to_s] }
  end

  # Find available slots for specific services (using service durations)
  # @param service_point_id [Integer] service point
  # @param date [Date] date
  # @param services [Array<Service>] services to book
  # @param car_type [String] car type for duration calculation
  # @return [Array<Hash>] available time windows
  def self.find_available_slots_for_services(service_point_id, date, services, car_type: nil)
    # Calculate total duration needed
    total_duration = services.sum do |service|
      service.duration_for_car_type(car_type)
    end

    find_available_slots_for_duration(service_point_id, date, total_duration)
  end

  # Extend reservation timeout for slots
  # @param session_id [String] session identifier
  # @param additional_minutes [Integer] minutes to add
  # @return [Hash] result
  def self.extend_reservation(session_id, additional_minutes: 5)
    slots = ScheduleSlot.reserved_by_session(session_id)

    return { success: false, error: 'no_reservations' } if slots.empty?

    extended_count = 0
    new_until = nil

    slots.each do |slot|
      new_until = slot.reserved_until + additional_minutes.minutes
      if slot.update(reserved_until: new_until)
        extended_count += 1
      end
    end

    {
      success: extended_count > 0,
      extended_count: extended_count,
      reserved_until: new_until,
      remaining_seconds: new_until ? (new_until - Time.current).to_i : 0
    }
  end

  # Confirm reservation and mark as booked
  # @param session_id [String] session that has the reservation
  # @param slot_ids [Array<Integer>] slots to confirm
  # @return [Hash] result
  def self.confirm_reservation(session_id, slot_ids)
    slots = ScheduleSlot.where(id: slot_ids, reserved_by_session: session_id)

    return { success: false, error: 'slots_not_found' } if slots.empty?

    confirmed_count = 0
    slots.each do |slot|
      confirmed_count += 1 if slot.confirm!
    end

    {
      success: confirmed_count == slot_ids.length,
      confirmed_count: confirmed_count
    }
  end

  private

  # Check if slots are consecutive (same post, adjacent times)
  def self.slots_are_consecutive?(slots)
    return true if slots.length <= 1

    sorted = slots.sort_by(&:start_time)
    post_id = sorted.first.service_post_id

    sorted.each_cons(2) do |slot1, slot2|
      # Must be same post
      return false unless slot2.service_post_id == post_id

      # End time of first must match start time of second
      return false unless slot1.end_time == slot2.start_time
    end

    true
  end

  # Calculate total duration from a set of slots
  def self.calculate_total_duration(slots)
    return 0 if slots.empty?

    sorted = slots.sort_by(&:start_time)
    first_slot = sorted.first
    last_slot = sorted.last

    start_minutes = first_slot.start_time.hour * 60 + first_slot.start_time.min
    end_minutes = last_slot.end_time.hour * 60 + last_slot.end_time.min

    end_minutes - start_minutes
  end

  # Find consecutive slot windows that can accommodate a given duration
  def self.find_consecutive_windows(slots, required_duration)
    return [] if slots.empty?

    sorted = slots.sort_by(&:start_time)
    windows = []

    sorted.each_with_index do |start_slot, start_idx|
      current_slots = [start_slot]
      current_duration = start_slot.duration_in_minutes

      # Try to extend window with consecutive slots
      (start_idx + 1...sorted.length).each do |next_idx|
        next_slot = sorted[next_idx]

        # Check if next slot is consecutive
        if current_slots.last.end_time == next_slot.start_time
          current_slots << next_slot
          current_duration += next_slot.duration_in_minutes

          # If we have enough duration, record this window
          if current_duration >= required_duration
            windows << {
              slots: current_slots.dup,
              start_time: current_slots.first.start_time,
              end_time: current_slots.last.end_time,
              duration: current_duration
            }
          end
        else
          # Gap found, can't extend further
          break
        end
      end

      # Also check if single slot is enough
      if start_slot.duration_in_minutes >= required_duration && !windows.any? { |w| w[:slots] == [start_slot] }
        windows << {
          slots: [start_slot],
          start_time: start_slot.start_time,
          end_time: start_slot.end_time,
          duration: start_slot.duration_in_minutes
        }
      end
    end

    windows
  end
end 