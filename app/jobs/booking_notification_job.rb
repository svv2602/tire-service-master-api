class BookingNotificationJob < ApplicationJob
  queue_as :notifications

  # Handle permanently failed jobs
  sidekiq_retries_exhausted do |msg, _ex|
    Rails.logger.error "[BookingNotificationJob] Permanently failed: #{msg['error_message']}"
    SystemLog.create(
      action: 'job_permanently_failed',
      resource_type: 'BookingNotificationJob',
      resource_id: msg['args']&.first,
      additional_data: { error: msg['error_message'], job_id: msg['jid'], args: msg['args'] }
    ) rescue nil
    AdminNotificationService.notify_job_permanently_failed(
      job_class: 'BookingNotificationJob',
      error_message: msg['error_message'],
      job_id: msg['jid']
    ) if defined?(AdminNotificationService)
  end

  # Отправка уведомления о бронировании
  def perform(booking_id, notification_type, recipient_email = nil)
    booking = Booking.find_by(id: booking_id)
    return unless booking

    Rails.logger.info "📧 BookingNotificationJob: booking_id=#{booking_id}, type=#{notification_type}"

    # Определяем email получателя (если не передан явно)
    if recipient_email.blank?
      recipient_email = booking.service_recipient_email || booking.client&.email
      return unless recipient_email.present?
    end

    # Отправляем уведомление через EmailTemplateMailer в зависимости от типа
    case notification_type.to_s
    when 'booking_created'
      EmailTemplateMailer.booking_confirmation(booking_id, recipient_email).deliver_later
      Rails.logger.info "✅ Запланировано подтверждение создания бронирования на #{recipient_email}"
    when 'booking_confirmed'
      EmailTemplateMailer.booking_confirmation(booking_id, recipient_email).deliver_later
      Rails.logger.info "✅ Запланировано подтверждение бронирования на #{recipient_email}"
    when 'booking_cancelled'
      EmailTemplateMailer.booking_cancelled(booking_id, recipient_email).deliver_later
      Rails.logger.info "✅ Запланировано уведомление об отмене на #{recipient_email}"
    when 'booking_reminder'
      EmailTemplateMailer.booking_reminder(booking_id, recipient_email).deliver_later
      Rails.logger.info "✅ Запланировано напоминание о бронировании на #{recipient_email}"
    when 'service_completed'
      EmailTemplateMailer.service_completed(booking_id, recipient_email).deliver_later
      Rails.logger.info "✅ Запланировано уведомление о завершении услуги на #{recipient_email}"
    when 'booking_time_changed'
      EmailTemplateMailer.booking_time_changed(booking_id, recipient_email).deliver_later
      Rails.logger.info "✅ Запланировано уведомление об изменении времени на #{recipient_email}"
    when 'booking_location_changed'
      EmailTemplateMailer.booking_location_changed(booking_id, recipient_email).deliver_later
      Rails.logger.info "✅ Запланировано уведомление об изменении места на #{recipient_email}"
    when 'booking_client_info_changed'
      EmailTemplateMailer.booking_client_info_changed(booking_id, recipient_email).deliver_later
      Rails.logger.info "✅ Запланировано уведомление об изменении данных клиента на #{recipient_email}"
    
    # === ADMIN УВЕДОМЛЕНИЯ ===
    when 'admin_new_booking'
      EmailTemplateMailer.admin_new_booking(booking_id, recipient_email).deliver_now
    when 'admin_booking_changed'
      EmailTemplateMailer.admin_booking_changed(booking_id, recipient_email).deliver_now
    when 'admin_booking_cancelled'
      EmailTemplateMailer.admin_booking_cancelled(booking_id, recipient_email).deliver_now
    
    # === ADMIN УВЕДОМЛЕНИЯ ОБ ОТЗЫВАХ ===
    when 'admin_new_review'
      review = Review.find_by(id: booking_id) # booking_id здесь на самом деле review_id
      if review && recipient_email.present?
        EmailTemplateMailer.admin_new_review(review.id, recipient_email).deliver_now
      end
    
    # === УВЕДОМЛЕНИЯ КЛИЕНТАМ ОБ ОТЗЫВАХ ===
    when 'review_published'
      review = Review.find_by(id: booking_id) # booking_id здесь на самом деле review_id
      if review && recipient_email.present?
        EmailTemplateMailer.review_published(review.id, recipient_email).deliver_now
      end
    when 'review_rejected'
      review = Review.find_by(id: booking_id) # booking_id здесь на самом деле review_id
      if review && recipient_email.present?
        EmailTemplateMailer.review_rejected(review.id, recipient_email).deliver_now
      end
    
    # === TELEGRAM УВЕДОМЛЕНИЯ ===
    when 'telegram_booking_created'
      send_telegram_notification(booking_id, 'booking_confirmation')
    when 'telegram_booking_changed'
      send_telegram_notification(booking_id, 'booking_changed')
    when 'telegram_booking_cancelled'
      send_telegram_notification(booking_id, 'booking_cancelled')
    when 'telegram_booking_time_changed'
      send_telegram_notification(booking_id, 'booking_time_changed')
    when 'telegram_booking_location_changed'
      send_telegram_notification(booking_id, 'booking_location_changed')
    when 'telegram_booking_cancelled'
      send_telegram_notification(booking_id, 'booking_cancelled')
    
    # === TELEGRAM УВЕДОМЛЕНИЯ ОБ ОТЗЫВАХ ===
    when 'telegram_admin_new_review'
      send_telegram_review_notification(booking_id, 'admin_new_review') # booking_id здесь review_id
    when 'telegram_review_published'
      send_telegram_review_notification(booking_id, 'review_published') # booking_id здесь review_id
    when 'telegram_review_rejected'
      send_telegram_review_notification(booking_id, 'review_rejected') # booking_id здесь review_id
    
    # === ADMIN УВЕДОМЛЕНИЯ О СЕРВИСНЫХ ТОЧКАХ ===
    when 'admin_service_point_created'
      service_point = ServicePoint.find_by(id: booking_id) # booking_id здесь service_point_id
      if service_point && recipient_email.present?
        EmailTemplateMailer.admin_service_point_created(service_point.id, recipient_email).deliver_now
      end
    when 'admin_service_point_changed'
      service_point = ServicePoint.find_by(id: booking_id) # booking_id здесь service_point_id
      if service_point && recipient_email.present?
        EmailTemplateMailer.admin_service_point_changed(service_point.id, recipient_email).deliver_now
      end
    when 'admin_service_point_status_changed'
      service_point = ServicePoint.find_by(id: booking_id) # booking_id здесь service_point_id
      if service_point && recipient_email.present?
        EmailTemplateMailer.admin_service_point_status_changed(service_point.id, recipient_email).deliver_now
      end
    
    # === TELEGRAM УВЕДОМЛЕНИЯ О СЕРВИСНЫХ ТОЧКАХ ===
    when 'telegram_admin_service_point_created'
      send_telegram_service_point_notification(booking_id, 'admin_service_point_created') # booking_id здесь service_point_id
    when 'telegram_admin_service_point_changed'
      send_telegram_service_point_notification(booking_id, 'admin_service_point_changed') # booking_id здесь service_point_id
    when 'telegram_admin_service_point_status_changed'
      send_telegram_service_point_notification(booking_id, 'admin_service_point_status_changed') # booking_id здесь service_point_id

    # === ПАРТНЁРСКИЕ УВЕДОМЛЕНИЯ ===
    when 'partner_new_booking'
      # Email уведомление партнёру о новой записи
      send_partner_booking_email(booking_id, recipient_email)
    when 'push_partner_new_booking'
      # Push уведомление партнёру о новой записи
      send_partner_push_notification(booking_id)
    when 'telegram_partner_new_booking'
      # Telegram уведомление партнёру о новой записи
      send_partner_telegram_notification(booking_id)
    when 'push_operator_new_booking'
      # Push уведомление оператору о новой записи
      # recipient_email здесь содержит user_id оператора
      send_operator_push_notification(booking_id, recipient_email.to_i)

    # === ПАРТНЁРСКИЕ УВЕДОМЛЕНИЯ ОБ ОТМЕНЕ ===
    when 'partner_booking_cancelled'
      # Email уведомление партнёру об отмене записи
      send_partner_booking_cancelled_email(booking_id, recipient_email)
    when 'push_partner_booking_cancelled'
      # Push уведомление партнёру об отмене записи
      send_partner_cancelled_push_notification(booking_id)
    when 'telegram_partner_booking_cancelled'
      # Telegram уведомление партнёру об отмене записи
      send_partner_cancelled_telegram_notification(booking_id)
    when 'push_operator_booking_cancelled'
      # Push уведомление оператору об отмене записи
      send_operator_cancelled_push_notification(booking_id, recipient_email.to_i)
    else
      Rails.logger.warn "⚠️ Неизвестный тип уведомления: #{notification_type}"
    end
  end

  private

  # Получение иконки для Push уведомления по типу
  def get_push_icon_for_notification_type(notification_type)
    case notification_type
    when 'booking_confirmation'
      '/icons/booking-confirmed.png'
    when 'booking_cancelled'
      '/icons/booking-cancelled.png'
    when 'booking_reminder'
      '/icons/booking-reminder.png'
    when 'service_completed'
      '/icons/service-completed.png'
    when 'review_request'
      '/icons/review-request.png'
    else
      '/icon-192x192.png'
    end
  end

  # Получение действий для Push уведомления
  def get_push_actions_for_notification_type(notification_type, booking)
    case notification_type
    when 'booking_confirmation'
      [
        { action: 'view', title: 'Переглянути', icon: '/icons/view.png' },
        { action: 'reschedule', title: 'Перенести', icon: '/icons/reschedule.png' }
      ]
    when 'booking_reminder'
      [
        { action: 'view', title: 'Деталі', icon: '/icons/view.png' },
        { action: 'directions', title: 'Маршрут', icon: '/icons/directions.png' }
      ]
    when 'service_completed'
      [
        { action: 'review', title: 'Залишити відгук', icon: '/icons/review.png' },
        { action: 'view', title: 'Переглянути', icon: '/icons/view.png' }
      ]
    when 'review_request'
      [
        { action: 'review', title: 'Залишити відгук', icon: '/icons/review.png' },
        { action: 'dismiss', title: 'Пізніше', icon: '/icons/dismiss.png' }
      ]
    else
      []
    end
  end

  # Отправка Telegram уведомления
  def send_telegram_notification(booking_id, notification_type)
    booking = Booking.find_by(id: booking_id)
    return unless booking

    Rails.logger.info "📱 Отправка Telegram уведомления: #{notification_type} для бронирования ##{booking_id}"

    # Ищем пользователя по email или телефону
    user = find_user_for_booking(booking)
    return unless user&.telegram_subscription&.can_receive_notifications?

    # Создаем сообщение на основе типа уведомления
    message = build_telegram_message(booking, notification_type)
    return unless message

    # Отправляем через TelegramService
    telegram_service = TelegramService.new
    success = telegram_service.send_notification(
      user,
      message,
      {
        type: notification_type,
        booking: booking
      }
    )

    if success
      Rails.logger.info "✅ Telegram уведомление отправлено пользователю #{user.id}"
    else
      Rails.logger.error "❌ Не удалось отправить Telegram уведомление пользователю #{user.id}"
    end
  rescue => e
    Rails.logger.error "❌ Ошибка отправки Telegram уведомления: #{e.message}"
  end

  # Отправка Push уведомления
  def send_push_notification(booking_id, notification_type)
    booking = Booking.find_by(id: booking_id)
    return unless booking

    Rails.logger.info "🔔 Отправка Push уведомления: #{notification_type} для бронирования ##{booking_id}"

    # Ищем пользователя по email или телефону
    user = find_user_for_booking(booking)
    return unless user&.push_subscriptions&.any? { |sub| sub.can_receive_notifications? }

    # Создаем сообщение на основе типа уведомления
    message_data = build_push_message(booking, notification_type)
    return unless message_data

    # Отправляем через PushService
    push_service = PushService.new
    success = push_service.send_notification(
      user,
      message_data[:title],
      message_data[:body],
      {
        type: notification_type,
        booking_id: booking.id,
        url: "/my-bookings",
        icon: get_push_icon_for_notification_type(notification_type),
        actions: get_push_actions_for_notification_type(notification_type, booking)
      }
    )

    if success
      Rails.logger.info "✅ Push уведомление отправлено пользователю #{user.id}"
    else
      Rails.logger.error "❌ Не удалось отправить Push уведомление пользователю #{user.id}"
    end
  rescue => e
    Rails.logger.error "❌ Ошибка отправки Push уведомления: #{e.message}"
  end

  # Отправка Telegram уведомления об отзыве
  def send_telegram_review_notification(review_id, notification_type)
    review = Review.find_by(id: review_id)
    return unless review

    Rails.logger.info "📱 Отправка Telegram уведомления об отзыве: #{notification_type} для отзыва ##{review_id}"

    # Ищем пользователя по email или телефону
    user = find_user_for_booking(review.booking) # Используем booking из отзыва
    return unless user&.telegram_subscription&.can_receive_notifications?

    # Создаем сообщение на основе типа уведомления
    message = build_telegram_review_message(review, notification_type)
    return unless message

    # Отправляем через TelegramService
    telegram_service = TelegramService.new
    success = telegram_service.send_notification(
      user,
      message,
      {
        type: notification_type,
        review: review
      }
    )

    if success
      Rails.logger.info "✅ Telegram уведомление об отзыве отправлено пользователю #{user.id}"
    else
      Rails.logger.error "❌ Не удалось отправить Telegram уведомление об отзыве пользователю #{user.id}"
    end
  rescue => e
    Rails.logger.error "❌ Ошибка отправки Telegram уведомления об отзыве: #{e.message}"
  end

  # Отправка Telegram уведомления о сервисной точке
  def send_telegram_service_point_notification(service_point_id, notification_type)
    service_point = ServicePoint.find_by(id: service_point_id)
    return unless service_point

    Rails.logger.info "📱 Отправка Telegram уведомления о сервисной точке: #{notification_type} для сервисной точки ##{service_point_id}"

    # Получаем настройки Telegram для отправки админам
    settings = TelegramSetting.current
    return unless settings.enabled? && settings.admin_chat_id.present?

    # Создаем сообщение на основе типа уведомления
    message = build_telegram_service_point_message(service_point, notification_type)
    return unless message

    # Отправляем через TelegramService напрямую админам
    telegram_service = TelegramService.new
    response = telegram_service.send_message(settings.admin_chat_id, message)

    if response[:ok]
      Rails.logger.info "✅ Telegram уведомление о сервисной точке отправлено администратору"
    else
      Rails.logger.error "❌ Не удалось отправить Telegram уведомление о сервисной точке: #{response[:description]}"
    end
  rescue => e
    Rails.logger.error "❌ Ошибка отправки Telegram уведомления о сервисной точке: #{e.message}"
  end

  # Поиск пользователя для бронирования
  def find_user_for_booking(booking)
    # Сначала пытаемся найти по клиенту
    return booking.client.user if booking.client&.user

    # Затем по email получателя услуги
    if booking.service_recipient_email.present?
      user = User.find_by(email: booking.service_recipient_email)
      return user if user
    end

    # Затем по телефону получателя услуги
    if booking.service_recipient_phone.present?
      user = User.find_by(phone: booking.service_recipient_phone)
      return user if user
    end

    nil
  end

  # Построение сообщения для Telegram
  def build_telegram_message(booking, notification_type)
    # Используем TelegramService для форматирования с шаблонами из БД
    telegram_service = TelegramService.new
    telegram_service.format_booking_notification(booking, notification_type, 'uk')
  end

  # Построение сообщения для Telegram об отзыве
  def build_telegram_review_message(review, notification_type)
    # Используем TelegramService для форматирования с шаблонами из БД
    telegram_service = TelegramService.new
    
    # Для отзывов используем бронирование как контекст
    if review.booking
      telegram_service.format_booking_notification(review.booking, notification_type, 'uk')
    else
      # Fallback для отзывов без бронирования
      build_review_fallback_message(review, notification_type)
    end
  end

  # Построение Push уведомления
  def build_push_message(booking, notification_type)
    # Используем PushService для форматирования с шаблонами из БД
    push_service = PushService.new
    push_service.format_booking_notification(booking, notification_type, 'uk')
  end

  # Построение Push уведомления об отзыве
  def build_push_review_message(review, notification_type)
    # Используем PushService для форматирования с шаблонами из БД
    push_service = PushService.new
    
    # Для отзывов используем бронирование как контекст
    if review.booking
      push_service.format_booking_notification(review.booking, notification_type, 'uk')
    else
      # Fallback для отзывов без бронирования
      build_push_review_fallback_message(review, notification_type)
    end
  end

  # Построение сообщения для Telegram о сервисной точке
  def build_telegram_service_point_message(service_point, notification_type)
    case notification_type
    when 'admin_service_point_created'
      build_admin_service_point_created_message(service_point)
    when 'admin_service_point_changed'
      build_admin_service_point_changed_message(service_point)
    when 'admin_service_point_status_changed'
      build_admin_service_point_status_changed_message(service_point)
    else
      nil
    end
  end

  # Fallback для отзывов без бронирования
  def build_review_fallback_message(review, notification_type)
    case notification_type
    when 'admin_new_review'
      "⭐ <b>Новий відгук!</b>\n\n" \
      "Оцінка: #{review.rating}/5\n" \
      "Коментар: #{review.comment}\n" \
      "Від: #{review.client&.user&.full_name || 'Анонім'}"
    when 'review_published'
      "✅ <b>Ваш відгук опубліковано!</b>\n\n" \
      "Дякуємо за відгук про наш сервіс!"
    when 'review_rejected'
      "❌ <b>Ваш відгук не пройшов модерацію</b>\n\n" \
      "Будь ласка, зверніться до служби підтримки для уточнення деталей."
    else
      nil
    end
  end

  # Fallback для Push уведомлений об отзывах без бронирования
  def build_push_review_fallback_message(review, notification_type)
    case notification_type
    when 'admin_new_review'
      {
        title: 'Новий відгук!',
        body: "Оцінка: #{review.rating}/5 від #{review.client&.user&.full_name || 'Анонім'}"
      }
    when 'review_published'
      {
        title: 'Відгук опубліковано!',
        body: 'Дякуємо за відгук про наш сервіс!'
      }
    when 'review_rejected'
      {
        title: 'Відгук не пройшов модерацію',
        body: 'Зверніться до служби підтримки для уточнення деталей'
      }
    else
      {
        title: 'Tire Service',
        body: 'Оновлення відгуку'
      }
    end
  end

  # === ПАРТНЁРСКИЕ УВЕДОМЛЕНИЯ ===

  # Отправка Email уведомления партнёру о новой записи
  def send_partner_booking_email(booking_id, partner_email)
    booking = Booking.find_by(id: booking_id)
    return unless booking && partner_email.present?

    Rails.logger.info "📧 Отправка Email партнёру #{partner_email} о новой записи ##{booking_id}"

    EmailTemplateMailer.partner_new_booking(booking_id, partner_email).deliver_later

    Rails.logger.info "✅ Email партнёру запланирован"
  rescue => e
    Rails.logger.error "❌ Ошибка отправки Email партнёру: #{e.message}"
  end

  # Отправка Push уведомления партнёру о новой записи
  def send_partner_push_notification(booking_id)
    booking = Booking.find_by(id: booking_id)
    return unless booking

    partner = booking.service_point&.partner
    return unless partner&.user

    user = partner.user
    return unless user.push_subscriptions.any? { |sub| sub.can_receive_notifications? }

    Rails.logger.info "🔔 Отправка Push партнёру (user_id=#{user.id}) о новой записи ##{booking_id}"

    # Формируем данные для уведомления
    service_name = booking.services.first&.name || booking.service_category&.name || 'Послуга шиномонтажу'
    client_name = booking.service_recipient_full_name
    date = booking.booking_date&.strftime('%d.%m.%Y') || 'Не вказано'
    time = booking.start_time&.strftime('%H:%M') || 'Не вказано'

    push_service = PushService.new
    success = push_service.send_notification(
      user,
      '🆕 Нова запис!',
      "#{client_name} • #{date} о #{time}\n#{service_name}",
      {
        type: 'partner_new_booking',
        booking_id: booking.id,
        service_point_id: booking.service_point_id,
        url: "/admin/bookings",
        icon: '/icons/new-booking.png',
        require_interaction: true,
        tag: "booking-#{booking.id}",
        sound: true, # Флаг для звукового уведомления на фронтенде
        actions: [
          { action: 'confirm', title: 'Підтвердити', icon: '/icons/confirm.png' },
          { action: 'view', title: 'Переглянути', icon: '/icons/view.png' }
        ]
      }
    )

    if success
      Rails.logger.info "✅ Push партнёру отправлен"
    else
      Rails.logger.error "❌ Не удалось отправить Push партнёру"
    end
  rescue => e
    Rails.logger.error "❌ Ошибка отправки Push партнёру: #{e.message}"
  end

  # Отправка Telegram уведомления партнёру о новой записи
  def send_partner_telegram_notification(booking_id)
    booking = Booking.find_by(id: booking_id)
    return unless booking

    partner = booking.service_point&.partner
    return unless partner&.user

    user = partner.user
    return unless user.telegram_subscription&.can_receive_notifications?

    Rails.logger.info "📱 Отправка Telegram партнёру (user_id=#{user.id}) о новой записи ##{booking_id}"

    # Формируем сообщение
    message = build_partner_new_booking_telegram_message(booking)

    telegram_service = TelegramService.new
    success = telegram_service.send_notification(
      user,
      message,
      {
        type: 'partner_new_booking',
        booking: booking
      }
    )

    if success
      Rails.logger.info "✅ Telegram партнёру отправлен"
    else
      Rails.logger.error "❌ Не удалось отправить Telegram партнёру"
    end
  rescue => e
    Rails.logger.error "❌ Ошибка отправки Telegram партнёру: #{e.message}"
  end

  # Отправка Push уведомления оператору о новой записи
  def send_operator_push_notification(booking_id, user_id)
    booking = Booking.find_by(id: booking_id)
    return unless booking

    user = User.find_by(id: user_id)
    return unless user&.push_subscriptions&.any? { |sub| sub.can_receive_notifications? }

    Rails.logger.info "🔔 Отправка Push оператору (user_id=#{user_id}) о новой записи ##{booking_id}"

    # Формируем данные для уведомления
    service_name = booking.services.first&.name || booking.service_category&.name || 'Послуга шиномонтажу'
    client_name = booking.service_recipient_full_name
    date = booking.booking_date&.strftime('%d.%m.%Y') || 'Не вказано'
    time = booking.start_time&.strftime('%H:%M') || 'Не вказано'

    push_service = PushService.new
    success = push_service.send_notification(
      user,
      '🆕 Нова запис!',
      "#{client_name} • #{date} о #{time}\n#{service_name}",
      {
        type: 'operator_new_booking',
        booking_id: booking.id,
        service_point_id: booking.service_point_id,
        url: "/admin/operator-dashboard",
        icon: '/icons/new-booking.png',
        require_interaction: true,
        tag: "booking-#{booking.id}",
        sound: true,
        actions: [
          { action: 'view', title: 'Переглянути', icon: '/icons/view.png' }
        ]
      }
    )

    if success
      Rails.logger.info "✅ Push оператору отправлен"
    else
      Rails.logger.error "❌ Не удалось отправить Push оператору"
    end
  rescue => e
    Rails.logger.error "❌ Ошибка отправки Push оператору: #{e.message}"
  end

  # Построение Telegram сообщения для партнёра о новой записи
  def build_partner_new_booking_telegram_message(booking)
    service_name = booking.services.first&.name || booking.service_category&.name || 'Послуга шиномонтажу'
    client_name = booking.service_recipient_full_name
    client_phone = booking.service_recipient_phone
    date = booking.booking_date&.strftime('%d.%m.%Y') || 'Не вказано'
    time = booking.start_time&.strftime('%H:%M') || 'Не вказано'
    point_name = booking.service_point&.name || 'Сервісна точка'

    <<~MESSAGE
      🆕 <b>Нова запис!</b>

      📅 <b>Дата:</b> #{date}
      ⏰ <b>Час:</b> #{time}
      📍 <b>Точка:</b> #{point_name}

      👤 <b>Клієнт:</b> #{client_name}
      📱 <b>Телефон:</b> #{client_phone}

      🔧 <b>Послуга:</b> #{service_name}

      #{booking.status == 'pending' ? '⏳ Статус: Очікує підтвердження' : '✅ Статус: Підтверджено'}
    MESSAGE
  end

  # === УВЕДОМЛЕНИЯ ОБ ОТМЕНЕ ДЛЯ ПАРТНЁРОВ ===

  # Отправка Email уведомления партнёру об отмене записи
  def send_partner_booking_cancelled_email(booking_id, partner_email)
    booking = Booking.find_by(id: booking_id)
    return unless booking && partner_email.present?

    Rails.logger.info "📧 Отправка Email партнёру #{partner_email} об отмене записи ##{booking_id}"

    EmailTemplateMailer.partner_booking_cancelled(booking_id, partner_email).deliver_later

    Rails.logger.info "✅ Email партнёру об отмене запланирован"
  rescue => e
    Rails.logger.error "❌ Ошибка отправки Email партнёру об отмене: #{e.message}"
  end

  # Отправка Push уведомления партнёру об отмене записи
  def send_partner_cancelled_push_notification(booking_id)
    booking = Booking.find_by(id: booking_id)
    return unless booking

    partner = booking.service_point&.partner
    return unless partner&.user

    user = partner.user
    return unless user.push_subscriptions.any? { |sub| sub.can_receive_notifications? }

    Rails.logger.info "🔔 Отправка Push партнёру (user_id=#{user.id}) об отмене записи ##{booking_id}"

    # Формируем данные для уведомления
    service_name = booking.services.first&.name || booking.service_category&.name || 'Послуга шиномонтажу'
    client_name = booking.service_recipient_full_name
    date = booking.booking_date&.strftime('%d.%m.%Y') || 'Не вказано'
    time = booking.start_time&.strftime('%H:%M') || 'Не вказано'

    push_service = PushService.new
    success = push_service.send_notification(
      user,
      '❌ Запис скасовано',
      "#{client_name} • #{date} о #{time}\n#{service_name}",
      {
        type: 'partner_booking_cancelled',
        booking_id: booking.id,
        service_point_id: booking.service_point_id,
        url: "/admin/bookings",
        icon: '/icons/booking-cancelled.png',
        require_interaction: true,
        tag: "booking-cancelled-#{booking.id}",
        actions: [
          { action: 'view', title: 'Переглянути', icon: '/icons/view.png' }
        ]
      }
    )

    if success
      Rails.logger.info "✅ Push партнёру об отмене отправлен"
    else
      Rails.logger.error "❌ Не удалось отправить Push партнёру об отмене"
    end
  rescue => e
    Rails.logger.error "❌ Ошибка отправки Push партнёру об отмене: #{e.message}"
  end

  # Отправка Telegram уведомления партнёру об отмене записи
  def send_partner_cancelled_telegram_notification(booking_id)
    booking = Booking.find_by(id: booking_id)
    return unless booking

    partner = booking.service_point&.partner
    return unless partner&.user

    user = partner.user
    return unless user.telegram_subscription&.can_receive_notifications?

    Rails.logger.info "📱 Отправка Telegram партнёру (user_id=#{user.id}) об отмене записи ##{booking_id}"

    # Формируем сообщение
    message = build_partner_booking_cancelled_telegram_message(booking)

    telegram_service = TelegramService.new
    success = telegram_service.send_notification(
      user,
      message,
      {
        type: 'partner_booking_cancelled',
        booking: booking
      }
    )

    if success
      Rails.logger.info "✅ Telegram партнёру об отмене отправлен"
    else
      Rails.logger.error "❌ Не удалось отправить Telegram партнёру об отмене"
    end
  rescue => e
    Rails.logger.error "❌ Ошибка отправки Telegram партнёру об отмене: #{e.message}"
  end

  # Отправка Push уведомления оператору об отмене записи
  def send_operator_cancelled_push_notification(booking_id, user_id)
    booking = Booking.find_by(id: booking_id)
    return unless booking

    user = User.find_by(id: user_id)
    return unless user&.push_subscriptions&.any? { |sub| sub.can_receive_notifications? }

    Rails.logger.info "🔔 Отправка Push оператору (user_id=#{user_id}) об отмене записи ##{booking_id}"

    # Формируем данные для уведомления
    service_name = booking.services.first&.name || booking.service_category&.name || 'Послуга шиномонтажу'
    client_name = booking.service_recipient_full_name
    date = booking.booking_date&.strftime('%d.%m.%Y') || 'Не вказано'
    time = booking.start_time&.strftime('%H:%M') || 'Не вказано'

    push_service = PushService.new
    success = push_service.send_notification(
      user,
      '❌ Запис скасовано',
      "#{client_name} • #{date} о #{time}\n#{service_name}",
      {
        type: 'operator_booking_cancelled',
        booking_id: booking.id,
        service_point_id: booking.service_point_id,
        url: "/admin/operator-dashboard",
        icon: '/icons/booking-cancelled.png',
        require_interaction: true,
        tag: "booking-cancelled-#{booking.id}",
        actions: [
          { action: 'view', title: 'Переглянути', icon: '/icons/view.png' }
        ]
      }
    )

    if success
      Rails.logger.info "✅ Push оператору об отмене отправлен"
    else
      Rails.logger.error "❌ Не удалось отправить Push оператору об отмене"
    end
  rescue => e
    Rails.logger.error "❌ Ошибка отправки Push оператору об отмене: #{e.message}"
  end

  # Построение Telegram сообщения для партнёра об отмене записи
  def build_partner_booking_cancelled_telegram_message(booking)
    service_name = booking.services.first&.name || booking.service_category&.name || 'Послуга шиномонтажу'
    client_name = booking.service_recipient_full_name
    client_phone = booking.service_recipient_phone
    date = booking.booking_date&.strftime('%d.%m.%Y') || 'Не вказано'
    time = booking.start_time&.strftime('%H:%M') || 'Не вказано'
    point_name = booking.service_point&.name || 'Сервісна точка'

    <<~MESSAGE
      ❌ <b>Запис скасовано!</b>

      📅 <b>Дата:</b> #{date}
      ⏰ <b>Час:</b> #{time}
      📍 <b>Точка:</b> #{point_name}

      👤 <b>Клієнт:</b> #{client_name}
      📱 <b>Телефон:</b> #{client_phone}

      🔧 <b>Послуга:</b> #{service_name}

      ℹ️ Слот тепер доступний для нових записів
    MESSAGE
  end
end