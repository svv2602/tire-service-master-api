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
    def self.booking_notification(booking, type, additional_data = {})
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

    # Методы для конкретных типов уведомлений
    
    def self.send_booking_created(booking, data)
      send_notification(booking.client, 'booking_created', {
        title: 'Бронювання створено',
        message: "Ваш запис на #{booking.booking_date} о #{booking.start_time} створено",
        category: 'booking',
        priority: 'normal',
        template_type: 'booking_confirmation', # Используем EmailTemplate
        variables: build_booking_variables(booking),
        channels: ['push', 'email']
      }.merge(data))
    end
    
    def self.send_booking_confirmed(booking, data)
      send_notification(booking.client, 'booking_confirmed', {
        title: 'Бронювання підтверджено',
        message: "Ваш запис на #{booking.booking_date} о #{booking.start_time} підтверджено",
        category: 'booking',
        priority: 'high',
        template_type: 'booking_confirmation', # Используем EmailTemplate
        variables: build_booking_variables(booking),
        channels: ['push', 'email', 'sms']
      }.merge(data))
    end
    
    def self.send_booking_cancelled(booking, data)
      send_notification(booking.client, 'booking_cancelled', {
        title: 'Бронювання скасовано',
        message: "Ваш запис на #{booking.booking_date} о #{booking.start_time} скасовано",
        category: 'booking',
        priority: 'high',
        template_type: 'booking_cancelled', # Используем EmailTemplate
        variables: build_booking_variables(booking),
        channels: ['push', 'email', 'sms']
      }.merge(data))
    end
    
    def self.send_booking_reminder(booking, data)
      send_notification(booking.client, 'booking_reminder', {
        title: 'Нагадування про запис',
        message: "Нагадуємо про ваш запис завтра о #{booking.start_time}",
        category: 'reminder',
        priority: 'high',
        template_type: 'booking_reminder', # Используем EmailTemplate
        variables: build_booking_variables(booking),
        channels: ['push', 'email', 'sms']
      }.merge(data))
    end
    
    def self.send_booking_completed(booking, data)
      send_notification(booking.client, 'booking_completed', {
        title: 'Обслуговування завершено',
        message: 'Дякуємо за візит! Будь ласка, оцініть наш сервіс',
        category: 'booking',
        priority: 'normal',
        template_type: 'service_completed', # Используем EmailTemplate
        variables: build_booking_variables(booking),
        channels: ['push', 'email']
      }.merge(data))
    end

    # Создание уведомления о бронировании
    def self.booking_notification(booking, type, additional_data = {})
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

    # Строит переменные для бронирования (используется в EmailTemplate)
    def self.build_booking_variables(booking)
      variables = {
        # Системные переменные
        'company_name' => 'Tire Service Master',
        'support_email' => ENV.fetch('SUPPORT_EMAIL', 'support@tireservice.ua'),
        'support_phone' => ENV.fetch('SUPPORT_PHONE', '+38 (044) 111-22-33'),
        'website_url' => ENV.fetch('FRONTEND_URL', 'https://tireservice.ua'),
        'current_date' => Date.current.strftime('%d.%m.%Y'),
        'current_time' => Time.current.strftime('%H:%M')
      }

      # Клиент
      variables.merge!({
        'client_name' => "#{booking.service_recipient_first_name} #{booking.service_recipient_last_name}".strip,
        'client_email' => booking.service_recipient_email || booking.client&.email || '',
        'client_phone' => booking.service_recipient_phone || booking.client&.phone || '',
        'client_first_name' => booking.service_recipient_first_name || booking.client&.first_name || '',
        'client_last_name' => booking.service_recipient_last_name || booking.client&.last_name || ''
      })

      # Бронирование
      variables.merge!({
        'booking_id' => "##{booking.id}",
        'booking_date' => booking.booking_date&.strftime('%d.%m.%Y') || '',
        'booking_time' => booking.start_time&.strftime('%H:%M') || '',
        'booking_status' => booking.status&.humanize || ''
      })

      # Сервисная точка
      if booking.service_point
        variables.merge!({
          'service_point_name' => booking.service_point.name || '',
          'service_point_address' => booking.service_point.address || '',
          'service_point_phone' => booking.service_point.contact_phone_for_category(booking.service_category_id) || '',
          'service_point_city' => booking.service_point.city&.name || ''
        })
      end

      # Услуги
      if booking.service_category
        variables.merge!({
          'service_name' => booking.service_category.name || '',
          'service_category' => booking.service_category.name || ''
        })
      end

      # Автомобиль
      variables.merge!({
        'car_brand' => booking.car_brand || '',
        'car_model' => booking.car_model || '',
        'license_plate' => booking.license_plate || ''
      })

      variables
    end
  end

  def self.send_operator_assignment_notification(operator, service_point, action_type)
    new.send_operator_assignment_notification(operator, service_point, action_type)
  end

  def self.send_partner_operator_notification(partner, operator, action_type)
    new.send_partner_operator_notification(partner, operator, action_type)
  end

  def send_operator_assignment_notification(operator, service_point, action_type)
    return unless operator&.user&.email && service_point

    case action_type
    when 'assigned'
      send_operator_assigned_notification(operator, service_point)
    when 'unassigned'
      send_operator_unassigned_notification(operator, service_point)
    end
  end

  def send_partner_operator_notification(partner, operator, action_type)
    return unless partner&.user&.email && operator

    case action_type
    when 'operator_created'
      send_partner_new_operator_notification(partner, operator)
    when 'operator_activated'
      send_partner_operator_activated_notification(partner, operator)
    when 'operator_deactivated'
      send_partner_operator_deactivated_notification(partner, operator)
    end
  end

  private

  def prepare_notification_data(recipient, notification_type, data)
    # Данные по умолчанию
    default_data = {
      title: data[:title] || notification_type.name.humanize,
      message: data[:message] || 'No message provided',
      priority: data[:priority] || 'normal',
      category: data[:category] || 'general'
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

    # Используем новую систему EmailTemplate если доступна
    if data[:template_type].present?
      EmailTemplateMailer.send_by_template(
        data[:template_type],
        recipient_email,
        data[:variables] || {}
      ).deliver_later
      Rails.logger.info "Email отправлен через EmailTemplate: #{data[:template_type]} → #{recipient_email}"
    else
      # Fallback на старую систему
      NotificationMailer.general_notification(
        notification.id,
        recipient_email
      ).deliver_later
      Rails.logger.info "Email отправлен через NotificationMailer → #{recipient_email}"
    end
    
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

  def send_operator_assigned_notification(operator, service_point)
    # Email уведомление
    send_email_notification(
      to: operator.user.email,
      template: 'operator_assigned',
      variables: {
        operator_name: operator.user.full_name,
        service_point_name: service_point.name,
        service_point_address: service_point.address,
        partner_name: service_point.partner.name,
        assignment_date: Time.current.strftime('%d.%m.%Y'),
        working_hours: format_working_hours(service_point),
        contact_phone: service_point.phone,
        login_url: frontend_url('/admin/dashboard')
      }
    )

    # Telegram уведомление (если настроено)
    send_telegram_notification(
      user: operator.user,
      message: build_telegram_assignment_message(operator, service_point, 'assigned')
    )

    # Push уведомление (если настроено)
    send_push_notification(
      user: operator.user,
      title: 'Новое назначение',
      body: "Вы назначены на сервисную точку #{service_point.name}",
      data: {
        type: 'operator_assignment',
        service_point_id: service_point.id,
        action: 'assigned'
      }
    )

    # Внутреннее уведомление в системе
    create_internal_notification(
      user: operator.user,
      title: 'Назначение на сервисную точку',
      message: "Вы назначены оператором на сервисную точку \"#{service_point.name}\"",
      notification_type: 'operator_assignment',
      related_id: service_point.id,
      related_type: 'ServicePoint'
    )
  end

  def send_operator_unassigned_notification(operator, service_point)
    # Email уведомление
    send_email_notification(
      to: operator.user.email,
      template: 'operator_unassigned',
      variables: {
        operator_name: operator.user.full_name,
        service_point_name: service_point.name,
        service_point_address: service_point.address,
        partner_name: service_point.partner.name,
        unassignment_date: Time.current.strftime('%d.%m.%Y'),
        contact_phone: service_point.partner.user.phone,
        login_url: frontend_url('/admin/dashboard')
      }
    )

    # Telegram уведомление
    send_telegram_notification(
      user: operator.user,
      message: build_telegram_assignment_message(operator, service_point, 'unassigned')
    )

    # Push уведомление
    send_push_notification(
      user: operator.user,
      title: 'Отзыв назначения',
      body: "Ваше назначение на сервисную точку #{service_point.name} отозвано",
      data: {
        type: 'operator_unassignment',
        service_point_id: service_point.id,
        action: 'unassigned'
      }
    )

    # Внутреннее уведомление
    create_internal_notification(
      user: operator.user,
      title: 'Отзыв назначения',
      message: "Ваше назначение на сервисную точку \"#{service_point.name}\" отозвано",
      notification_type: 'operator_unassignment',
      related_id: service_point.id,
      related_type: 'ServicePoint'
    )
  end

  def send_partner_new_operator_notification(partner, operator)
    send_email_notification(
      to: partner.user.email,
      template: 'partner_new_operator',
      variables: {
        partner_name: partner.user.full_name,
        operator_name: operator.user.full_name,
        operator_email: operator.user.email,
        operator_phone: operator.user.phone,
        creation_date: Time.current.strftime('%d.%m.%Y'),
        manage_operators_url: frontend_url('/admin/operators')
      }
    )

    create_internal_notification(
      user: partner.user,
      title: 'Новый оператор',
      message: "Создан новый оператор: #{operator.user.full_name}",
      notification_type: 'new_operator',
      related_id: operator.id,
      related_type: 'Operator'
    )
  end

  def send_partner_operator_activated_notification(partner, operator)
    create_internal_notification(
      user: partner.user,
      title: 'Оператор активирован',
      message: "Оператор #{operator.user.full_name} активирован",
      notification_type: 'operator_activated',
      related_id: operator.id,
      related_type: 'Operator'
    )
  end

  def send_partner_operator_deactivated_notification(partner, operator)
    create_internal_notification(
      user: partner.user,
      title: 'Оператор деактивирован',
      message: "Оператор #{operator.user.full_name} деактивирован",
      notification_type: 'operator_deactivated',
      related_id: operator.id,
      related_type: 'Operator'
    )
  end

  def build_telegram_assignment_message(operator, service_point, action_type)
    case action_type
    when 'assigned'
      "🎯 *Новое назначение*\n\n" \
      "Здравствуйте, #{operator.user.first_name}!\n\n" \
      "Вы назначены оператором на сервисную точку:\n" \
      "📍 *#{service_point.name}*\n" \
      "📧 #{service_point.address}\n" \
      "📞 #{service_point.phone}\n\n" \
      "Партнер: #{service_point.partner.name}\n" \
      "Дата назначения: #{Time.current.strftime('%d.%m.%Y')}\n\n" \
      "Войдите в систему для управления бронированиями."
    when 'unassigned'
      "⚠️ *Отзыв назначения*\n\n" \
      "Здравствуйте, #{operator.user.first_name}!\n\n" \
      "Ваше назначение на сервисную точку отозвано:\n" \
      "📍 *#{service_point.name}*\n" \
      "📧 #{service_point.address}\n\n" \
      "Дата отзыва: #{Time.current.strftime('%d.%m.%Y')}\n\n" \
      "Обратитесь к партнеру для уточнения деталей."
    end
  end

  def format_working_hours(service_point)
    # Форматируем часы работы для отображения в уведомлениях
    # Здесь можно добавить логику форматирования расписания
    "Пн-Пт: 9:00-18:00, Сб-Вс: 10:00-16:00" # Заглушка
  end

  def send_email_notification(to:, template:, variables:)
    # Интеграция с существующей системой email уведомлений
    EmailNotificationJob.perform_later(
      to: to,
      template: template,
      variables: variables
    )
  rescue => e
    Rails.logger.error "Ошибка отправки email уведомления: #{e.message}"
  end

  def send_telegram_notification(user:, message:)
    # Интеграция с существующей системой Telegram уведомлений
    TelegramNotificationJob.perform_later(
      user_id: user.id,
      message: message
    )
  rescue => e
    Rails.logger.error "Ошибка отправки Telegram уведомления: #{e.message}"
  end

  def send_push_notification(user:, title:, body:, data: {})
    # Интеграция с существующей системой Push уведомлений
    PushNotificationJob.perform_later(
      user_id: user.id,
      title: title,
      body: body,
      data: data
    )
  rescue => e
    Rails.logger.error "Ошибка отправки Push уведомления: #{e.message}"
  end

  def create_internal_notification(user:, title:, message:, notification_type:, related_id: nil, related_type: nil)
    # Создание внутреннего уведомления в системе
    Notification.create!(
      user: user,
      title: title,
      message: message,
      notification_type: notification_type,
      related_id: related_id,
      related_type: related_type,
      is_read: false,
      created_at: Time.current
    )
  rescue => e
    Rails.logger.error "Ошибка создания внутреннего уведомления: #{e.message}"
  end

  def frontend_url(path)
    # Генерация URL для frontend приложения
    base_url = Rails.application.credentials.frontend_url || 'http://localhost:3008'
    "#{base_url}#{path}"
  end
end 