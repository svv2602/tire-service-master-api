class BookingManager
  # Создает новое бронирование
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
end 