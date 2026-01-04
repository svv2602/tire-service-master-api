class BookingManager
  # Result structure for consistent return values
  Result = Struct.new(:success, :data, :error, keyword_init: true) do
    def success?
      success
    end
  end

  # ==================== AVAILABILITY CHECKING ====================

  # Check availability for a booking
  # @param service_point_id [Integer] service point
  # @param date [Date] booking date
  # @param start_time [String] preferred start time
  # @param services [Array<Hash>] services with :service_id and optional :quantity
  # @param car_type [String] car type for duration calculation
  # @param session_id [String] optional session for reservation check
  # @return [Result] availability result
  def self.check_availability(service_point_id:, date:, start_time: nil, services: [], car_type: nil, session_id: nil)
    service_point = ServicePoint.find_by(id: service_point_id)
    return Result.new(success: false, error: 'service_point_not_found') unless service_point
    return Result.new(success: false, error: 'service_point_inactive') unless service_point.active?

    # Calculate required duration
    duration = calculate_duration_for_services(services, car_type)

    # Find available slots
    options = {}
    options[:start_time] = start_time if start_time.present?

    available_windows = ScheduleManager.find_available_slots_for_duration(
      service_point_id, date, duration, options
    )

    if available_windows.any?
      Result.new(
        success: true,
        data: {
          available: true,
          duration_minutes: duration,
          available_windows: available_windows,
          earliest_slot: available_windows.first,
          total_windows: available_windows.count
        }
      )
    else
      # Find next available date
      next_slot = find_next_available_slot_for_services(service_point_id, date, services, car_type)

      Result.new(
        success: true,
        data: {
          available: false,
          duration_minutes: duration,
          available_windows: [],
          next_available: next_slot
        }
      )
    end
  rescue StandardError => e
    Rails.logger.error "[BookingManager] check_availability error: #{e.message}"
    Result.new(success: false, error: e.message)
  end

  # Calculate total duration for a set of services
  # @param services [Array<Hash>] services with :service_id
  # @param car_type [String] car type name
  # @return [Integer] duration in minutes
  def self.calculate_duration_for_services(services, car_type = nil)
    return 30 if services.blank?

    car_type ||= 'sedan'
    service_ids = services.map { |s| s[:service_id] || s['service_id'] }
    service_records = Service.where(id: service_ids)

    total = service_records.sum do |service|
      service.duration_for_car_type(car_type)
    end

    total.positive? ? total : 30
  end

  # Find optimal time slots for a booking
  # @param service_point_id [Integer] service point
  # @param date [Date] preferred date
  # @param services [Array<Hash>] services to book
  # @param car_type [String] car type
  # @param preferred_time [String] optional preferred time
  # @return [Result] optimal slots
  def self.find_optimal_slots(service_point_id:, date:, services: [], car_type: nil, preferred_time: nil)
    duration = calculate_duration_for_services(services, car_type)

    options = {}
    options[:start_time] = preferred_time if preferred_time.present?

    available_windows = ScheduleManager.find_available_slots_for_duration(
      service_point_id, date, duration, options
    )

    # Sort by preference (closer to preferred time is better)
    if preferred_time.present?
      preferred_minutes = parse_time_to_minutes(preferred_time)
      available_windows = available_windows.sort_by do |window|
        window_minutes = parse_time_to_minutes(window[:start_time].strftime('%H:%M'))
        (window_minutes - preferred_minutes).abs
      end
    end

    Result.new(
      success: true,
      data: {
        date: date,
        duration_minutes: duration,
        optimal_slots: available_windows.first(5),
        total_available: available_windows.count
      }
    )
  rescue StandardError => e
    Rails.logger.error "[BookingManager] find_optimal_slots error: #{e.message}"
    Result.new(success: false, error: e.message)
  end

  # ==================== BOOKING CREATION ====================

  # Create a booking with slot reservation
  # @param params [Hash] booking parameters
  # @option params [Integer] :client_id (optional for guest bookings)
  # @option params [Integer] :service_point_id required
  # @option params [Date] :booking_date required
  # @option params [String] :start_time required
  # @option params [Array<Hash>] :services services to book
  # @option params [Integer] :car_type_id required
  # @option params [String] :session_id optional session for slot reservation
  # @option params [Hash] :recipient_info guest recipient info
  # @return [Result] booking result
  def self.create_with_slots(params)
    ActiveRecord::Base.transaction do
      # Validate service point
      service_point = ServicePoint.find(params[:service_point_id])
      unless service_point.active?
        return Result.new(success: false, error: 'service_point_inactive')
      end

      # Calculate duration
      car_type = CarType.find_by(id: params[:car_type_id])
      duration = calculate_duration_for_services(params[:services] || [], car_type&.name)

      # Build booking attributes
      booking_attrs = build_booking_attributes(params, duration)

      # Create booking
      booking = Booking.new(booking_attrs)
      booking.skip_availability_check = false

      # If session_id provided, try to use reserved slots
      if params[:session_id].present?
        booking.reserve_slots_from_session(params[:session_id])
      end

      if booking.save
        # Add services
        add_services_to_booking(booking, params[:services]) if params[:services].present?

        Result.new(success: true, data: { booking: booking })
      else
        Result.new(success: false, error: booking.errors.full_messages.join(', '))
      end
    end
  rescue ActiveRecord::RecordNotFound => e
    Result.new(success: false, error: 'record_not_found')
  rescue StandardError => e
    Rails.logger.error "[BookingManager] create_with_slots error: #{e.message}"
    Result.new(success: false, error: e.message)
  end

  # Legacy method - Создает новое бронирование
  def self.create(client_id:, service_point_id:, booking_date:, start_time:, end_time:, services: [], car_id: nil, car_type_id: nil)
    ActiveRecord::Base.transaction do
      # Проверяем, что клиент существует
      client = Client.find(client_id)
      
      # Проверяем, что точка обслуживания существует и активна
      service_point = ServicePoint.find(service_point_id)
      unless service_point.active?
        raise StandardError, "Service point is not active"
      end
      
      # Проверяем, что указан хотя бы ID автомобиля или типа автомобиля
      if car_id.nil? && car_type_id.nil?
        raise StandardError, "Either car_id or car_type_id must be specified"
      end
      
      # Проверяем наличие свободного слота в расписании
      slot = find_or_create_slot(service_point_id, booking_date, start_time, end_time)
      
      # Если слот не найден, возвращаем ошибку
      unless slot
        raise StandardError, "No available slot found for the specified time"
      end
      
      # Проверяем, что услуги существуют
      service_ids = services.map { |s| s[:service_id] }
      unless Service.where(id: service_ids).count == service_ids.size
        raise StandardError, "One or more services do not exist"
      end
      
      # Рассчитываем общую стоимость
      total_price = calculate_total_price(service_point_id, services)
      
      # Получаем статус "pending"
      pending_status = BookingStatus.find_by(name: 'pending')
      if pending_status.nil?
        pending_status = BookingStatus.create!(
          name: 'pending',
          description: 'Waiting for confirmation',
          color: '#FFC107',
          is_active: true
        )
      end
      
      # Получаем статус оплаты "not_paid"
      not_paid_status = PaymentStatus.find_by(name: 'not_paid')
      if not_paid_status.nil?
        not_paid_status = PaymentStatus.create!(
          name: 'not_paid',
          description: 'Not paid yet',
          color: '#F44336',
          is_active: true
        )
      end
      
      # Создаем бронирование
      booking = Booking.create!(
        client_id: client_id,
        service_point_id: service_point_id,
        car_id: car_id,
        car_type_id: car_type_id || (car_id ? ClientCar.find(car_id).car_type_id : nil),
        slot_id: slot.id,
        booking_date: booking_date,
        start_time: start_time,
        end_time: end_time,
        status_id: pending_status.id,
        payment_status_id: not_paid_status.id,
        total_price: total_price
      )
      
      # Добавляем услуги в бронирование
      add_services_to_booking(booking, services)
      
      # Создаем уведомление о новом бронировании
      create_booking_notification(booking)
      
      booking
    end
  end
  
  # Подтверждает бронирование
  def self.confirm(booking_id)
    ActiveRecord::Base.transaction do
      booking = Booking.find(booking_id)
      
      # Проверяем, что бронирование находится в статусе "pending"
      pending_status = BookingStatus.find_by(name: 'pending')
      unless booking.status_id == pending_status.id
        raise StandardError, "Booking is not in pending status"
      end
      
      # Получаем статус "confirmed"
      confirmed_status = BookingStatus.find_by(name: 'confirmed')
      if confirmed_status.nil?
        confirmed_status = BookingStatus.create!(
          name: 'confirmed',
          description: 'Confirmed by service point',
          color: '#4CAF50',
          is_active: true
        )
      end
      
      # Обновляем статус бронирования
      booking.update!(status_id: confirmed_status.id)
      
      # Создаем уведомление о подтверждении бронирования
      create_confirmation_notification(booking)
      
      booking
    end
  end
  
  # Отменяет бронирование
  def self.cancel(booking_id, cancellation_reason_id, comment = nil, cancelled_by = 'client')
    ActiveRecord::Base.transaction do
      booking = Booking.find(booking_id)
      
      # Проверяем, что бронирование можно отменить (находится в статусе pending или confirmed)
      allowed_statuses = BookingStatus.where(name: ['pending', 'confirmed']).pluck(:id)
      unless allowed_statuses.include?(booking.status_id)
        raise StandardError, "Booking cannot be cancelled in its current status"
      end
      
      # Проверяем, что причина отмены существует
      cancellation_reason = CancellationReason.find(cancellation_reason_id)
      
      # Получаем статус отмены в зависимости от того, кто отменил
      status_name = cancelled_by == 'client' ? 'canceled_by_client' : 'canceled_by_partner'
      cancellation_status = BookingStatus.find_by(name: status_name)
      if cancellation_status.nil?
        cancellation_status = BookingStatus.create!(
          name: status_name,
          description: cancelled_by == 'client' ? 'Cancelled by client' : 'Cancelled by service point',
          color: '#F44336',
          is_active: true
        )
      end
      
      # Обновляем бронирование
      booking.update!(
        status_id: cancellation_status.id,
        cancellation_reason_id: cancellation_reason_id,
        cancellation_comment: comment
      )
      
      # Освобождаем слот расписания, если это возможно
      # В реальном приложении здесь может быть более сложная логика
      
      # Создаем уведомление об отмене бронирования
      create_cancellation_notification(booking, cancelled_by)
      
      booking
    end
  end
  
  private
  
  # Находит или создает слот расписания для бронирования
  def self.find_or_create_slot(service_point_id, booking_date, start_time, end_time)
    # Сначала ищем существующий доступный слот
    slot = ScheduleSlot.where(
      service_point_id: service_point_id,
      slot_date: booking_date,
      start_time: start_time,
      end_time: end_time,
      is_available: true
    ).first
    
    return slot if slot
    
    # Если слот не найден, проверяем, есть ли конфликты со временем
    conflicting_slots = ScheduleSlot.where(
      service_point_id: service_point_id,
      slot_date: booking_date
    ).where(
      "start_time < ? AND end_time > ?", end_time, start_time
    )
    
    if conflicting_slots.exists?
      return nil
    end
    
    # Если конфликтов нет, находим свободный пост
    service_point = ServicePoint.find(service_point_id)
    used_posts = ScheduleSlot.where(
      service_point_id: service_point_id,
      slot_date: booking_date,
      start_time: start_time
    ).pluck(:post_number)
    
    available_post = nil
    1.upto(service_point.post_count) do |post_number|
      unless used_posts.include?(post_number)
        available_post = post_number
        break
      end
    end
    
    if available_post.nil?
      return nil
    end
    
    # Создаем новый слот
    ScheduleSlot.create!(
      service_point_id: service_point_id,
      slot_date: booking_date,
      start_time: start_time,
      end_time: end_time,
      post_number: available_post,
      is_available: true
    )
  end
  
  # Рассчитывает общую стоимость бронирования
  def self.calculate_total_price(service_point_id, services)
    total = 0
    
    services.each do |service_data|
      service = Service.find(service_data[:service_id])
      quantity = service_data[:quantity] || 1
      
      # Получаем цену услуги для данной точки обслуживания
      price = service.current_price_for_service_point(service_point_id)
      
      # Если цена не найдена, используем базовую цену
      price ||= service.base_price
      
      total += price * quantity
    end
    
    total
  end
  
  # Добавляет услуги в бронирование
  def self.add_services_to_booking(booking, services)
    services.each do |service_data|
      service = Service.find(service_data[:service_id])
      quantity = service_data[:quantity] || 1
      
      # Получаем цену услуги для данной точки обслуживания
      price = service.current_price_for_service_point(booking.service_point_id)
      price ||= service.base_price
      
      # Создаем связь между бронированием и услугой
      BookingService.create!(
        booking_id: booking.id,
        service_id: service.id,
        price: price,
        quantity: quantity
      )
    end
  end
  
  # Создает уведомление о новом бронировании
  def self.create_booking_notification(booking)
    # Находим или создаем тип уведомления
    notification_type = NotificationType.find_or_create_by(
      name: 'new_booking',
      template: 'New booking #{booking_id} created for #{service_point_name} on #{booking_date}',
      is_push: true,
      is_email: true
    )
    
    # Создаем уведомление для клиента
    Notification.create!(
      notification_type_id: notification_type.id,
      recipient_type: 'Client',
      recipient_id: booking.client_id,
      title: 'New booking created',
      message: "Your booking ##{booking.id} for #{booking.service_point.name} on #{booking.booking_date.strftime('%d.%m.%Y')} has been created.",
      send_via: 'push'
    )
    
    # Находим менеджеров данной сервисной точки
    manager_ids = Manager.joins(:manager_service_points)
      .where(manager_service_points: { service_point_id: booking.service_point_id })
      .pluck(:id)
    
    # Создаем уведомления для менеджеров
    manager_ids.each do |manager_id|
      Notification.create!(
        notification_type_id: notification_type.id,
        recipient_type: 'Manager',
        recipient_id: manager_id,
        title: 'New booking received',
        message: "New booking ##{booking.id} for #{booking.service_point.name} on #{booking.booking_date.strftime('%d.%m.%Y')} has been created.",
        send_via: 'push'
      )
    end
  end
  
  # Создает уведомление о подтверждении бронирования
  def self.create_confirmation_notification(booking)
    # Находим или создаем тип уведомления
    notification_type = NotificationType.find_or_create_by(
      name: 'booking_confirmed',
      template: 'Booking #{booking_id} for #{service_point_name} on #{booking_date} has been confirmed',
      is_push: true,
      is_email: true
    )
    
    # Создаем уведомление для клиента
    Notification.create!(
      notification_type_id: notification_type.id,
      recipient_type: 'Client',
      recipient_id: booking.client_id,
      title: 'Booking confirmed',
      message: "Your booking ##{booking.id} for #{booking.service_point.name} on #{booking.booking_date.strftime('%d.%m.%Y')} has been confirmed.",
      send_via: 'push'
    )
  end
  
  # Создает уведомление об отмене бронирования
  def self.create_cancellation_notification(booking, cancelled_by)
    # Находим или создаем тип уведомления
    notification_type = NotificationType.find_or_create_by(
      name: 'booking_cancelled',
      template: 'Booking #{booking_id} for #{service_point_name} on #{booking_date} has been cancelled',
      is_push: true,
      is_email: true
    )
    
    if cancelled_by == 'client'
      # Уведомление для менеджеров
      manager_ids = Manager.joins(:manager_service_points)
        .where(manager_service_points: { service_point_id: booking.service_point_id })
        .pluck(:id)
      
      manager_ids.each do |manager_id|
        Notification.create!(
          notification_type_id: notification_type.id,
          recipient_type: 'Manager',
          recipient_id: manager_id,
          title: 'Booking cancelled',
          message: "Booking ##{booking.id} for #{booking.service_point.name} on #{booking.booking_date.strftime('%d.%m.%Y')} has been cancelled by the client.",
          send_via: 'push'
        )
      end
    else
      # Уведомление для клиента
      Notification.create!(
        notification_type_id: notification_type.id,
        recipient_type: 'Client',
        recipient_id: booking.client_id,
        title: 'Booking cancelled',
        message: "Your booking ##{booking.id} for #{booking.service_point.name} on #{booking.booking_date.strftime('%d.%m.%Y')} has been cancelled by the service point.",
        send_via: 'push'
      )
    end
  end

  # ==================== HELPER METHODS ====================

  # Build booking attributes from params
  def self.build_booking_attributes(params, duration)
    attrs = {
      service_point_id: params[:service_point_id],
      booking_date: params[:booking_date],
      start_time: params[:start_time],
      car_type_id: params[:car_type_id],
      calculated_duration_minutes: duration
    }

    # Set end_time from duration
    if params[:start_time].present? && duration.present?
      start_datetime = Time.parse("#{params[:booking_date]} #{params[:start_time]}")
      attrs[:end_time] = (start_datetime + duration.minutes).strftime('%H:%M')
    end

    # Client info (optional for guest bookings)
    attrs[:client_id] = params[:client_id] if params[:client_id].present?
    attrs[:car_id] = params[:car_id] if params[:car_id].present?

    # Recipient info
    if params[:recipient_info].present?
      recipient = params[:recipient_info]
      attrs[:service_recipient_first_name] = recipient[:first_name]
      attrs[:service_recipient_last_name] = recipient[:last_name]
      attrs[:service_recipient_phone] = recipient[:phone]
      attrs[:service_recipient_email] = recipient[:email]
    end

    # Car info for guest bookings
    if params[:car_info].present?
      car = params[:car_info]
      attrs[:car_brand] = car[:brand]
      attrs[:car_model] = car[:model]
      attrs[:license_plate] = car[:license_plate]
    end

    # Session ID for slot reservation
    attrs[:booking_session_id] = params[:session_id] if params[:session_id].present?

    # Service category
    attrs[:service_category_id] = params[:service_category_id] if params[:service_category_id].present?

    attrs
  end

  # Find next available slot for services across future dates
  def self.find_next_available_slot_for_services(service_point_id, from_date, services, car_type)
    duration = calculate_duration_for_services(services, car_type)
    max_days = 30

    (1..max_days).each do |day_offset|
      check_date = from_date + day_offset.days

      available_windows = ScheduleManager.find_available_slots_for_duration(
        service_point_id, check_date, duration
      )

      if available_windows.any?
        return {
          date: check_date,
          start_time: available_windows.first[:start_time].strftime('%H:%M'),
          end_time: available_windows.first[:end_time].strftime('%H:%M'),
          post_number: available_windows.first[:post_number]
        }
      end
    end

    nil
  end

  # Parse time string to minutes since midnight
  def self.parse_time_to_minutes(time_str)
    return 0 unless time_str.present?

    parts = time_str.to_s.split(':')
    return 0 unless parts.length >= 2

    parts[0].to_i * 60 + parts[1].to_i
  end
end 