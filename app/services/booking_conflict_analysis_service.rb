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
    reasons = []
    
    # Используем DynamicAvailabilityService для проверки доступности слота
    available_slots = DynamicAvailabilityService.available_slots_for_category(
      booking.service_point.id, 
      booking_date, 
      booking.service_category_id
    )
    
    # Проверяем, есть ли доступный слот для этого времени
    slot_available = available_slots.any? { |slot| slot[:time] == booking_time }
    
    unless slot_available
      # Если слот недоступен, проверяем причины
      has_working_posts = DynamicAvailabilityService.has_working_posts_for_category_on_date?(
        booking.service_point, 
        booking_date, 
        booking.service_category_id
      )
      
      if has_working_posts
        reasons << "Время #{booking_time} недоступно в текущем расписании на #{booking_date.strftime('%d.%m.%Y')}"
      else
        reasons << "Нет рабочих постов для категории '#{booking.service_category&.name}' на #{booking_date.strftime('%d.%m.%Y')}"
      end
      
      # Определяем тип конфликта
      conflict_type = determine_conflict_type(booking)
      conflict_reason = reasons.join('. ')
      
      # Создаем или обновляем конфликт
      return create_or_update_conflict(booking, conflict_type, conflict_reason)
    end
    
    # Если слот доступен, конфликта нет
    nil
  end

  def determine_conflict_type(booking)
    service_point = booking.service_point
    
    # Проверяем статус сервисной точки
    unless service_point.work_status == 'working'
      return 'service_point_status'
    end
    
    # Проверяем статус постов
    working_posts = service_point.service_posts.active
    if working_posts.empty?
      return 'post_status'
    end
    
    # По умолчанию - изменение расписания
    'schedule_change'
  end

  def generate_conflict_reason(booking, booking_date, booking_time)
    service_point = booking.service_point
    reasons = []
    
    # Проверяем различные причины конфликта
    unless service_point.work_status == 'working'
      reasons << "Сервисная точка '#{service_point.name}' имеет статус '#{service_point.work_status}'"
    end
    
    working_posts = service_point.service_posts.active
    if working_posts.empty?
      reasons << "Нет активных постов обслуживания"
    end
    
    # Проверяем расписание
    has_working_posts = DynamicAvailabilityService.has_working_posts_for_category_on_date?(
      service_point, 
      booking_date, 
      booking.service_category_id
    )
    
    if has_working_posts
      reasons << "Время #{booking_time} недоступно в текущем расписании на #{booking_date.strftime('%d.%m.%Y')}"
    else
      reasons << "Нет рабочих постов для категории '#{booking.service_category&.name}' на #{booking_date.strftime('%d.%m.%Y')}"
    end
    
    reasons.join('. ')
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

  def get_future_bookings_for_service_point(service_point)
    end_date = analysis_date + 30.days
    
    Booking.joins(:service_point)
           .where(service_point: service_point)
           .where('booking_date >= ? AND booking_date <= ?', analysis_date, end_date)
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