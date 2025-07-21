class BookingNotificationJob < ApplicationJob
  queue_as :notifications

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
      EmailTemplateMailer.booking_cancellation(booking_id, recipient_email).deliver_later
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
    else
      Rails.logger.warn "⚠️ Неизвестный тип уведомления: #{notification_type}"
    end
  end

  private

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
    # Сначала ищем по email
    user = User.find_by(email: booking.service_recipient_email) if booking.service_recipient_email.present?
    
    # Если не найден, ищем по телефону
    user ||= User.find_by(phone: booking.service_recipient_phone) if booking.service_recipient_phone.present?
    
    # Если есть связанный клиент, берем его пользователя
    user ||= booking.client&.user if booking.client

    user
  end

  # Построение сообщения для Telegram
  def build_telegram_message(booking, notification_type)
    case notification_type
    when 'booking_confirmation'
      build_booking_confirmation_message(booking)
    when 'booking_changed'
      build_booking_changed_message(booking)
    when 'booking_cancelled'
      build_booking_cancelled_message(booking)
    when 'booking_time_changed'
      build_booking_time_changed_message(booking)
    when 'booking_location_changed'
      build_booking_location_changed_message(booking)
    else
      nil
    end
  end

  # Построение сообщения для Telegram об отзыве
  def build_telegram_review_message(review, notification_type)
    case notification_type
    when 'admin_new_review'
      build_admin_new_review_message(review)
    when 'review_published'
      build_review_published_message(review)
    when 'review_rejected'
      build_review_rejected_message(review)
    else
      nil
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

  # Шаблоны сообщений для Telegram
  def build_booking_confirmation_message(booking)
    %{
✅ <b>Ваш запис підтверджено!</b>

📋 <b>Деталі бронювання:</b>
• Номер: ##{booking.id}
• Дата: #{booking.booking_date&.strftime('%d.%m.%Y')}
• Час: #{booking.start_time&.strftime('%H:%M')}

🏢 <b>Сервісна точка:</b>
#{booking.service_point&.name}
📍 #{booking.service_point&.address}
🌐 #{booking.service_point&.city&.name}

🚗 <b>Автомобіль:</b>
#{booking.car_brand} #{booking.car_model}
🔢 Номер: #{booking.license_plate}

Очікуємо вас! 🚗✨
    }.strip
  end

  def build_booking_changed_message(booking)
    %{
🔄 <b>Ваше бронювання змінено</b>

📋 <b>Оновлені деталі:</b>
• Номер: ##{booking.id}
• Дата: #{booking.booking_date&.strftime('%d.%m.%Y')}
• Час: #{booking.start_time&.strftime('%H:%M')}

🏢 <b>Сервісна точка:</b>
#{booking.service_point&.name}
📍 #{booking.service_point&.address}

До зустрічі! 👋
    }.strip
  end

  def build_booking_cancelled_message(booking)
    %{
❌ <b>Ваше бронювання скасовано</b>

📋 <b>Деталі:</b>
• Номер: ##{booking.id}
• Дата: #{booking.booking_date&.strftime('%d.%m.%Y')}
• Час: #{booking.start_time&.strftime('%H:%M')}

Якщо у вас є питання, зверніться до підтримки.

Дякуємо за розуміння! 🙏
    }.strip
  end

  def build_booking_time_changed_message(booking)
    %{
⏰ <b>Змінено час вашого бронювання</b>

📋 <b>Нові деталі:</b>
• Номер: ##{booking.id}
• Дата: #{booking.booking_date&.strftime('%d.%m.%Y')}
• Новий час: #{booking.start_time&.strftime('%H:%M')}

🏢 #{booking.service_point&.name}
📍 #{booking.service_point&.address}

Очікуємо вас у новий час! ⏰
    }.strip
  end

  def build_booking_location_changed_message(booking)
    %{
📍 <b>Змінено місце обслуговування</b>

📋 <b>Деталі:</b>
• Номер: ##{booking.id}
• Дата: #{booking.booking_date&.strftime('%d.%m.%Y')}
• Час: #{booking.start_time&.strftime('%H:%M')}

🏢 <b>Нова сервісна точка:</b>
#{booking.service_point&.name}
📍 #{booking.service_point&.address}
🌐 #{booking.service_point&.city&.name}

Очікуємо вас за новою адресою! 🗺️
    }.strip
  end

  def build_admin_new_review_message(review)
    %{
📝 <b>Новий відгук!</b>

📋 <b>Деталі відгуку:</b>
• Номер: ##{review.id}
• Оцінка: ⭐ #{review.rating}/5
• Статус: #{review.status}
#{review.comment.present? ? "• Коментар: #{review.comment}" : "• Без коментаря"}

👤 <b>Клієнт:</b>
#{review.client.first_name} #{review.client.last_name}
📧 #{review.client.email}

🏢 <b>Сервісна точка:</b>
#{review.service_point.name}
📍 #{review.service_point.address}

Потрібна модерація! 🔍
     }.strip
   end

   def build_review_published_message(review)
     %{
✅ <b>Ваш відгук опубліковано!</b>

📋 <b>Деталі відгуку:</b>
• Номер: ##{review.id}
• Оцінка: ⭐ #{review.rating}/5
#{review.comment.present? ? "• Коментар: #{review.comment}" : "• Без коментаря"}

🏢 <b>Сервісна точка:</b>
#{review.service_point.name}
📍 #{review.service_point.address}

Дякуємо за відгук! 🙏
     }.strip
   end

   def build_review_rejected_message(review)
     %{
❌ <b>Ваш відгук відхилено</b>

📋 <b>Деталі відгуку:</b>
• Номер: ##{review.id}
• Оцінка: ⭐ #{review.rating}/5
#{review.comment.present? ? "• Коментар: #{review.comment}" : "• Без коментаря"}

🏢 <b>Сервісна точка:</b>
#{review.service_point.name}

📞 З питань зверніться до підтримки
Дякуємо за розуміння! 🙏
     }.strip
   end

   def build_admin_service_point_created_message(service_point)
     %{
✅ <b>Нова сервісна точка створена!</b>

📋 <b>Деталі сервісної точки:</b>
• Назва: #{service_point.name}
• Адреса: #{service_point.address}
• Місто: #{service_point.city&.name}

🌐 <b>Контакти:</b>
📞 #{service_point.contact_phone}

Дякуємо за додавання сервісної точки! 🙏
     }.strip
   end

   def build_admin_service_point_changed_message(service_point)
     %{
🔄 <b>Сервісна точка оновлена</b>

📋 <b>Оновлені деталі:</b>
• Назва: #{service_point.name}
• Адреса: #{service_point.address}
• Місто: #{service_point.city&.name}

🌐 <b>Контакти:</b>
📞 #{service_point.contact_phone}

Дякуємо за оновлення сервісної точки! 🙏
     }.strip
   end

   def build_admin_service_point_status_changed_message(service_point)
     %{
⚙️ <b>Статус сервісної точки змінено</b>

🏢 <b>Деталі:</b>
• Назва: #{service_point.name}
• Статус: #{service_point.work_status}
• Активна: #{service_point.is_active? ? 'Так' : 'Ні'}

🌐 <b>Контакти:</b>
📞 #{service_point.contact_phone}

Дякуємо за зміну статусу сервісної точки! 🙏
     }.strip
   end
end 