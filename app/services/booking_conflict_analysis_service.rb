class BookingConflictAnalysisService < ApplicationService
  attr_reader :service_point, :post, :seasonal_schedule, :analysis_date

  def initialize(service_point: nil, post: nil, seasonal_schedule: nil, analysis_date: nil)
    @service_point = service_point
    @post = post
    @seasonal_schedule = seasonal_schedule
    @analysis_date = analysis_date || Date.current
  end

  def call
    conflicts = []

    if service_point.present?
      conflicts += analyze_service_point_conflicts
    elsif post.present?
      conflicts += analyze_post_conflicts
    elsif seasonal_schedule.present?
      conflicts += analyze_seasonal_schedule_conflicts
    else
      conflicts += analyze_all_conflicts
    end

    conflicts
  end

  private

  def analyze_service_point_conflicts
    conflicts = []
    
    # Получаем все будущие бронирования для сервисной точки (следующие 30 дней)
    future_bookings = get_future_bookings_for_service_point(service_point)
    
    future_bookings.each do |booking|
      conflict = check_booking_conflict(booking)
      conflicts << conflict if conflict
    end

    conflicts
  end

  def analyze_post_conflicts
    conflicts = []
    
    # Получаем все будущие бронирования для поста
    future_bookings = get_future_bookings_for_post(post)
    
    future_bookings.each do |booking|
      conflict = check_booking_conflict(booking)
      conflicts << conflict if conflict
    end

    conflicts
  end

  def analyze_seasonal_schedule_conflicts
    conflicts = []
    
    # Получаем все будущие бронирования для сервисной точки с сезонным расписанием
    future_bookings = get_future_bookings_for_service_point(seasonal_schedule.service_point)
    
    future_bookings.each do |booking|
      conflict = check_booking_conflict(booking)
      conflicts << conflict if conflict
    end

    conflicts
  end

  def analyze_all_conflicts
    conflicts = []
    
    # Анализируем все будущие бронирования в системе
    future_bookings = get_all_future_bookings
    
    future_bookings.each do |booking|
      conflict = check_booking_conflict(booking)
      conflicts << conflict if conflict
    end

    conflicts
  end

  def check_booking_conflict(booking)
    return nil if booking.start_time.blank? || booking.booking_date.blank?
    
    booking_date = booking.booking_date
    booking_time = booking.start_time.strftime('%H:%M')
    
    # 1. ПРОВЕРКА ВРЕМЕННОГО КОНФЛИКТА - время недоступно в расписании
    time_conflict = check_time_availability_conflict(booking, booking_date, booking_time)
    return time_conflict if time_conflict
    
    # 2. ПРОВЕРКА КОНФЛИКТА ЗАГРУЖЕННОСТИ - больше бронирований чем постов
    capacity_conflict = check_capacity_conflict(booking, booking_date, booking_time)
    return capacity_conflict if capacity_conflict
    
    # Если конфликтов нет, удаляем существующие конфликты для этого бронирования
    cleanup_resolved_conflicts(booking)
    
    nil
  end

  # Проверка временного конфликта - время недоступно в расписании
  def check_time_availability_conflict(booking, booking_date, booking_time)
    # Проверяем, есть ли работающие посты для данной категории в этот день
    has_working_posts = DynamicAvailabilityService.has_working_posts_for_category_on_date?(
      booking.service_point, 
      booking_date, 
      booking.service_category_id
    )
    
    unless has_working_posts
      conflict_reason = "Нет рабочих постов для категории '#{booking.service_category&.name}' на #{booking_date.strftime('%d.%m.%Y')}"
      conflict_type = determine_conflict_type(booking)
      return create_or_update_conflict(booking, conflict_type, conflict_reason)
    end
    
    # Проверяем, генерируются ли слоты для этого времени
    all_possible_slots = DynamicAvailabilityService.get_all_possible_slots_for_category(
      booking.service_point.id,
      booking_date,
      booking.service_category_id
    )
    
    time_slot_exists = all_possible_slots.any? { |slot| slot[:start_time] == booking_time }
    
    unless time_slot_exists
      conflict_reason = "Время #{booking_time} недоступно в текущем расписании на #{booking_date.strftime('%d.%m.%Y')}"
      conflict_type = 'schedule_change'
      return create_or_update_conflict(booking, conflict_type, conflict_reason)
    end
    
    nil
  end

  # Проверка конфликта загруженности - больше бронирований чем постов
  def check_capacity_conflict(booking, booking_date, booking_time)
    # Подсчитываем количество бронирований на это время (исключая текущее)
    bookings_at_time = Booking.where(
      service_point_id: booking.service_point_id,
      booking_date: booking_date,
      start_time: "#{booking_time}:00",
      service_category_id: booking.service_category_id
    ).where.not(
      status: ['cancelled_by_client', 'cancelled_by_partner', 'completed']
    ).where.not(id: booking.id).count
    
    # Включаем текущее бронирование в подсчет
    total_bookings = bookings_at_time + 1
    
    # Подсчитываем количество доступных постов для этой категории в это время
    available_posts = count_available_posts_for_category_at_time(
      booking.service_point,
      booking_date,
      booking_time,
      booking.service_category_id
    )
    
    # Если бронирований больше чем постов - это конфликт загруженности
    if total_bookings > available_posts
      conflict_reason = "Конфликт загруженности: #{total_bookings} бронирований на #{available_posts} постов в #{booking_time} #{booking_date.strftime('%d.%m.%Y')}"
      conflict_type = 'capacity_overload'
      return create_or_update_conflict(booking, conflict_type, conflict_reason)
    end
    
    nil
  end

  # Подсчет доступных постов для категории в конкретное время
  def count_available_posts_for_category_at_time(service_point, date, time, category_id)
    day_key = case date.wday
    when 0 then 'sunday'
    when 1 then 'monday'
    when 2 then 'tuesday'
    when 3 then 'wednesday'
    when 4 then 'thursday'
    when 5 then 'friday'
    when 6 then 'saturday'
    end
    
    # Получаем расписание для этой даты
    schedule_info = DynamicAvailabilityService.get_schedule_for_date(service_point, date)
    
    # Получаем посты для указанной категории
    category_posts = service_point.service_posts.where(service_category_id: category_id, is_active: true)
    
    # Считаем посты, работающие в этот день и время
    working_posts_count = category_posts.count do |post|
      if post.has_custom_schedule?
        # Пост имеет индивидуальный график
        next false unless post.working_on_day?(day_key)
        
        # Проверяем время работы поста
        start_time_str = post.start_time_for_day(day_key)
        end_time_str = post.end_time_for_day(day_key)
        
        if start_time_str && end_time_str
          post_start = Time.parse("#{date} #{start_time_str}")
          post_end = Time.parse("#{date} #{end_time_str}")
          check_time = Time.parse("#{date} #{time}")
          
          check_time >= post_start && check_time < post_end
        else
          false
        end
      else
        # Пост работает по общему расписанию
        next false unless schedule_info[:is_working]
        
        if schedule_info[:opening_time] && schedule_info[:closing_time]
          check_time = Time.parse("#{date} #{time}")
          check_time >= schedule_info[:opening_time] && check_time < schedule_info[:closing_time]
        else
          false
        end
      end
    end
    
    working_posts_count
  end

  def determine_conflict_type(booking)
    service_point = booking.service_point
    
    # Проверяем статус сервисной точки
    unless service_point.work_status == 'working'
      return 'service_point_status'
    end
    
    # Проверяем статус постов для конкретной категории
    category_posts = service_point.service_posts.where(service_category_id: booking.service_category_id)
    working_posts = category_posts.active
    
    if working_posts.empty?
      return 'post_status'
    end
    
    # По умолчанию - изменение расписания
    'schedule_change'
  end

  def create_or_update_conflict(booking, conflict_type, conflict_reason)
    # Проверяем, есть ли уже конфликт для этого бронирования
    existing_conflict = BookingConflict.pending.find_by(booking: booking)
    
    if existing_conflict
      # Обновляем существующий конфликт
      existing_conflict.update!(
        conflict_type: conflict_type,
        conflict_reason: conflict_reason,
        detected_at: Time.current
      )
      existing_conflict
    else
      # Создаем новый конфликт
      BookingConflict.create!(
        booking: booking,
        conflict_type: conflict_type,
        conflict_reason: conflict_reason,
        detected_at: Time.current,
        status: 'pending'
      )
    end
  end

  # Очистка разрешенных конфликтов
  def cleanup_resolved_conflicts(booking)
    BookingConflict.pending.where(booking: booking).destroy_all
  end

  def get_future_bookings_for_service_point(service_point)
    end_date = analysis_date + 30.days
    
    Booking.joins(:service_point)
           .where(service_point: service_point)
           .where('booking_date >= ? AND booking_date <= ?', analysis_date, end_date)
           .where.not(status: ['cancelled_by_client', 'cancelled_by_partner', 'completed'])
           .includes(:service_category, :client)
           .order(:booking_date, :start_time)
  end

  def get_future_bookings_for_post(post)
    end_date = analysis_date + 30.days
    
    Booking.joins(:service_point)
           .where(service_point: post.service_point)
           .where('booking_date >= ? AND booking_date <= ?', analysis_date, end_date)
           .where.not(status: ['cancelled_by_client', 'cancelled_by_partner', 'completed'])
           .includes(:service_point, :service_category, :client)
           .order(:booking_date, :start_time)
  end

  def get_all_future_bookings
    end_date = analysis_date + 30.days
    
    Booking.where('booking_date >= ? AND booking_date <= ?', analysis_date, end_date)
           .where.not(status: ['cancelled_by_client', 'cancelled_by_partner', 'completed'])
           .includes(:service_point, :service_category, :client)
           .order(:booking_date, :start_time)
  end

  # Методы для превью (синхронный анализ)
  def self.preview_conflicts(service_point: nil, post: nil, seasonal_schedule: nil)
    service = new(
      service_point: service_point,
      post: post,
      seasonal_schedule: seasonal_schedule
    )
    
    service.call
  end

  # Метод для получения статистики конфликтов
  def self.conflict_statistics
    {
      total_pending: BookingConflict.pending.count,
      by_type: BookingConflict.pending.group(:conflict_type).count,
      recent: BookingConflict.recent.limit(5)
    }
  end
end 