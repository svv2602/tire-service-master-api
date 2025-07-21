class NotificationService
  # Константы для типов уведомлений
  NOTIFICATION_TYPES = {
    booking_created: 'booking_created',
    booking_confirmed: 'booking_confirmed',
    booking_cancelled: 'booking_cancelled',
    booking_completed: 'booking_completed',
    booking_reminder: 'booking_reminder',
    system_notification: 'system_notification',
    payment_successful: 'payment_successful',
    review_request: 'review_request'
  }.freeze

  class << self
    # Основной метод для создания и отправки уведомления
    def send_notification(recipient, type_name, data = {})
      # Ищем тип уведомления
      notification_type = NotificationType.find_by(name: type_name)
      return false unless notification_type&.is_active?

      # Получаем данные для создания уведомления
      notification_data = prepare_notification_data(recipient, notification_type, data)
      
      # Создаем уведомление в БД
      notification = create_notification(recipient, notification_type, notification_data)
      return false unless notification
      
      # Отправляем уведомление по указанным каналам
      send_channels = determine_channels(notification_type, data[:channels])
      send_via_channels(notification, send_channels, data)
      
      # Помечаем как отправленное
      notification.mark_as_sent!
      
      notification
    end

    # Создание уведомления о бронировании
    def booking_notification(booking, type, additional_data = {})
      case type
      when :created
        send_booking_created(booking, additional_data)
      when :confirmed
        send_booking_confirmed(booking, additional_data)
      when :cancelled
        send_booking_cancelled(booking, additional_data)
      when :reminder
        send_booking_reminder(booking, additional_data)
      when :completed
        send_booking_completed(booking, additional_data)
      end
    end

    # Системные уведомления
    def system_notification(recipients, title, message, priority: 'normal', category: 'system')
      recipients = [recipients] unless recipients.is_a?(Array)
      
      recipients.map do |recipient|
        send_notification(recipient, 'system_notification', {
          title: title,
          message: message,
          priority: priority,
          category: category,
          channels: ['push', 'email']
        })
    end
  end

    private
    
    def prepare_notification_data(recipient, notification_type, data)
      # Данные по умолчанию
      default_data = {
        title: data[:title] || notification_type.name.humanize,
        message: data[:message] || 'No message provided',
        priority: data[:priority] || 'normal',
        category: data[:category] || 'general',
        action_url: data[:action_url],
        expires_at: data[:expires_at]
      }
      
      # Если есть шаблон, заполняем его данными
      if notification_type.template.present? && data[:template_data]
        default_data[:message] = fill_template(notification_type.template, data[:template_data])
      end
      
      default_data
    end
    
    def create_notification(recipient, notification_type, data)
      # Определяем тип и ID получателя
      recipient_type = recipient.class.name
      recipient_id = recipient.id
      
      # Создаем уведомление
      Notification.create(
        notification_type: notification_type,
        recipient_type: recipient_type,
        recipient_id: recipient_id,
        title: data[:title],
        message: data[:message],
        priority: data[:priority],
        category: data[:category],
        send_via: data[:channels]&.first || 'push',
        action_url: data[:action_url],
        expires_at: data[:expires_at]
      )
    rescue => e
      Rails.logger.error "Failed to create notification: #{e.message}"
      nil
    end
    
    def determine_channels(notification_type, requested_channels = nil)
      # Если каналы заданы явно, используем их
      return requested_channels if requested_channels.present?
      
      # Иначе определяем на основе типа уведомления
      channels = []
      channels << 'push' if notification_type.is_push?
      channels << 'email' if notification_type.is_email?
      channels << 'sms' if notification_type.is_sms?
      
      channels.presence || ['push'] # По умолчанию push
    end
    
    def send_via_channels(notification, channels, data)
      channels.each do |channel|
        case channel.to_s
        when 'email'
          send_email_notification(notification, data)
        when 'push'
          send_push_notification(notification, data)
        when 'sms'
          send_sms_notification(notification, data)
        when 'telegram'
          send_telegram_notification(notification, data)
        end
      end
    end
    
    def send_email_notification(notification, data)
      return unless notification.recipient_type == 'User' || 
                   (notification.recipient_type == 'Client' && 
                    notification.recipient.user&.email.present?)
      
      recipient_email = if notification.recipient_type == 'User'
                         notification.recipient.email
                       else
                         notification.recipient.user&.email
                       end
      
      return unless recipient_email.present?

      # Отправляем через mailer
      NotificationMailer.general_notification(
        notification.id,
        recipient_email
      ).deliver_later
      
      Rails.logger.info "Email notification sent to #{recipient_email}"
    rescue => e
      Rails.logger.error "Failed to send email notification: #{e.message}"
    end
    
    def send_push_notification(notification, data)
      # Заглушка для push уведомлений
      # Здесь будет интеграция с Firebase FCM
      Rails.logger.info "Push notification sent for notification #{notification.id}"
    end
    
    def send_sms_notification(notification, data)
      # Заглушка для SMS уведомлений
      Rails.logger.info "SMS notification sent for notification #{notification.id}"
    end
    
    def send_telegram_notification(notification, data)
      # Заглушка для Telegram уведомлений
      Rails.logger.info "Telegram notification sent for notification #{notification.id}"
    end
    
    def fill_template(template, data)
      result = template.dup
    data.each do |key, value|
        result.gsub!("{{#{key}}}", value.to_s)
      end
      result
    end

    # Методы для конкретных типов уведомлений
    
    def send_booking_created(booking, data)
      send_notification(booking.client, 'booking_created', {
        title: 'Бронирование создано',
        message: "Ваша запись на #{booking.booking_date} в #{booking.start_time} создана",
        category: 'booking',
        priority: 'normal',
        template_data: {
          date: booking.booking_date,
          time: booking.start_time,
          service_point: booking.service_point.name
        },
        action_url: "/client/bookings/#{booking.id}",
        channels: ['push', 'email']
      }.merge(data))
    end
    
    def send_booking_confirmed(booking, data)
      send_notification(booking.client, 'booking_confirmed', {
        title: 'Бронирование подтверждено',
        message: "Ваша запись на #{booking.booking_date} в #{booking.start_time} подтверждена",
        category: 'booking',
        priority: 'high',
        template_data: {
          date: booking.booking_date,
          time: booking.start_time,
          service_point: booking.service_point.name
        },
        action_url: "/client/bookings/#{booking.id}",
        channels: ['push', 'email', 'sms']
      }.merge(data))
    end
    
    def send_booking_cancelled(booking, data)
      send_notification(booking.client, 'booking_canceled', {
        title: 'Бронирование отменено',
        message: "Ваша запись на #{booking.booking_date} в #{booking.start_time} отменена",
        category: 'booking',
        priority: 'high',
        template_data: {
          date: booking.booking_date,
          time: booking.start_time,
          service_point: booking.service_point.name
        },
        action_url: "/client/bookings",
        channels: ['push', 'email', 'sms']
      }.merge(data))
    end
    
    def send_booking_reminder(booking, data)
      send_notification(booking.client, 'booking_reminder', {
        title: 'Напоминание о записи',
        message: "Напоминаем о вашей записи завтра в #{booking.start_time}",
        category: 'reminder',
        priority: 'high',
        template_data: {
          time: booking.start_time,
          service_point: booking.service_point.name
        },
        action_url: "/client/bookings/#{booking.id}",
        channels: ['push', 'sms']
      }.merge(data))
    end
    
    def send_booking_completed(booking, data)
      send_notification(booking.client, 'booking_completed', {
        title: 'Обслуживание завершено',
        message: 'Спасибо за посещение! Пожалуйста, оцените наш сервис',
        category: 'booking',
        priority: 'normal',
        template_data: {
          service_point: booking.service_point.name
        },
        action_url: "/client/review/new?booking_id=#{booking.id}",
        channels: ['push', 'email']
      }.merge(data))
    end
  end
end 