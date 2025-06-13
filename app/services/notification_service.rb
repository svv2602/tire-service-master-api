class NotificationService
  # Типы уведомлений
  NOTIFICATION_TYPES = {
    booking_created: 'booking_created',
    booking_confirmed: 'booking_confirmed',
    booking_reminder: 'booking_reminder',
    booking_cancelled: 'booking_cancelled',
    booking_completed: 'booking_completed',
    partner_new_booking: 'partner_new_booking',
    partner_booking_cancelled: 'partner_booking_cancelled'
  }.freeze

  # Отправка уведомления о бронировании
  def self.send_booking_notification(booking, notification_type)
    return unless booking.present?

    # Отправка email клиенту
    case notification_type
    when NOTIFICATION_TYPES[:booking_created]
      BookingMailer.booking_created(booking.id).deliver_later
    when NOTIFICATION_TYPES[:booking_confirmed]
      BookingMailer.booking_confirmed(booking.id).deliver_later
    when NOTIFICATION_TYPES[:booking_reminder]
      BookingMailer.booking_reminder(booking.id).deliver_later
    when NOTIFICATION_TYPES[:booking_cancelled]
      BookingMailer.booking_cancelled(booking.id).deliver_later
    when NOTIFICATION_TYPES[:booking_completed]
      BookingMailer.booking_completed(booking.id).deliver_later
    end

    # Отправка email партнеру
    if booking.service_point && booking.service_point.partner
      partner_id = booking.service_point.partner_id
      
      case notification_type
      when NOTIFICATION_TYPES[:booking_created]
        BookingMailer.new_booking_notification(booking.id, partner_id).deliver_later
      when NOTIFICATION_TYPES[:booking_cancelled]
        BookingMailer.booking_cancelled_notification(booking.id, partner_id).deliver_later
      end
    end

    # Создание записи уведомления для клиента
    if booking.client && notification_type_record = NotificationType.find_by(name: notification_type)
      create_notification(
        recipient_type: 'Client',
        recipient_id: booking.client_id,
        notification_type: notification_type_record,
        data: {
          booking_id: booking.id,
          service_point_id: booking.service_point_id,
          booking_date: booking.booking_date,
          start_time: booking.start_time,
          end_time: booking.end_time
        }
      )
    end
  end

  # Отправка ежедневных напоминаний
  def self.send_daily_reminders
    tomorrow = Date.current + 1.day
    bookings = Booking.where(booking_date: tomorrow)
                      .where.not(status: [3, 4]) # Не отмененные или завершенные
                      .includes(:client, :service_point)

    bookings.find_each do |booking|
      send_booking_notification(booking, NOTIFICATION_TYPES[:booking_reminder])
    end
  end

  # Отправка напоминаний за 2 часа
  def self.send_booking_reminders
    current_time = Time.current
    two_hours_later = current_time + 2.hours
    today = Date.current

    # Находим записи, которые будут через 2 часа
    bookings = Booking.where(booking_date: today)
                      .where.not(status: [3, 4]) # Не отмененные или завершенные
                      .includes(:client, :service_point)

    bookings.each do |booking|
      # Проверяем, что запись начинается примерно через 2 часа
      booking_start_time = Time.parse("#{booking.booking_date} #{booking.start_time}")
      
      if booking_start_time > current_time && booking_start_time < two_hours_later
        send_booking_notification(booking, NOTIFICATION_TYPES[:booking_reminder])
      end
    end
  end

  # Отправка ежедневных сводок партнерам
  def self.send_daily_summaries
    tomorrow = Date.current + 1.day
    
    Partner.find_each do |partner|
      NotificationMailer.daily_summary(partner.id, tomorrow).deliver_later
    end
  end

  # Создание записи уведомления
  def self.create_notification(recipient_type:, recipient_id:, notification_type:, data: {})
    # Получаем шаблон уведомления
    template = notification_type.template

    # Рендерим шаблон с данными
    title, message = render_template(template, data)

    # Определяем каналы отправки
    send_via = []
    send_via << 'email' if notification_type.is_email
    send_via << 'push' if notification_type.is_push
    send_via << 'sms' if notification_type.is_sms

    # Создаем уведомления для каждого канала
    send_via.each do |channel|
      Notification.create(
        notification_type: notification_type,
        recipient_type: recipient_type,
        recipient_id: recipient_id,
        title: title,
        message: message,
        send_via: channel,
        data: data
      )
    end
  end

  # Обработка шаблонов
  def self.render_template(template, data)
    return ['Уведомление', 'Новое уведомление'] unless template.present?

    # Простая обработка шаблона с заменой переменных
    message = template.dup
    
    data.each do |key, value|
      message.gsub!("{{#{key}}}", value.to_s)
    end

    # Генерируем заголовок из первых 50 символов сообщения
    title = message.split('.').first || message[0..50]
    
    [title, message]
  end
end 