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
    
    # === АДМИНСКИЕ УВЕДОМЛЕНИЯ ===
    when 'admin_new_booking'
      EmailTemplateMailer.admin_new_booking(booking_id, recipient_email).deliver_later
      Rails.logger.info "✅ Запланировано админское уведомление о новом бронировании на #{recipient_email}"
    when 'admin_booking_changed'
      EmailTemplateMailer.admin_booking_changed(booking_id, recipient_email).deliver_later
      Rails.logger.info "✅ Запланировано админское уведомление об изменении бронирования на #{recipient_email}"
    when 'admin_booking_cancelled'
      EmailTemplateMailer.admin_booking_cancelled(booking_id, recipient_email).deliver_later
      Rails.logger.info "✅ Запланировано админское уведомление об отмене бронирования на #{recipient_email}"
    
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
end 