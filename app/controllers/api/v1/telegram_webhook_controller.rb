class Api::V1::TelegramWebhookController < ApplicationController
  skip_before_action :authenticate_request
  
  def webhook
    Rails.logger.info "📨 Telegram webhook called"
    
    begin
      body = request.body.read
      data = JSON.parse(body, symbolize_names: true)
      Rails.logger.info "📦 Webhook data: #{data}"
      
      if data[:message]
        process_message(data[:message])
      elsif data[:callback_query]
        process_callback_query(data[:callback_query])
      end
      
      head :ok
      
    rescue JSON::ParserError => e
      Rails.logger.error "JSON parse error: #{e.message}"
      head :bad_request
    rescue => e
      Rails.logger.error "Webhook error: #{e.message}"
      head :internal_server_error
    end
  end
  
  def show_config
    head :ok
  end
  
  private
  
  def process_message(message)
    chat_id = message[:chat][:id]
    text = message[:text]
    contact = message[:contact]
    
    # Сохраняем данные пользователя Telegram
    user_data = {
      telegram_id: message[:from][:id],
      first_name: message[:from][:first_name],
      last_name: message[:from][:last_name],
      username: message[:from][:username],
      phone: contact&.[](:phone_number)
    }
    Rails.cache.write("telegram_#{chat_id}_user_data", user_data, expires_in: 1.hour)
    
    Rails.logger.info "Processing: #{text || 'contact'} from #{chat_id}"
    Rails.logger.info "👤 User data: #{user_data}"
    
    # Обработка команд
    if text&.start_with?('/')
      telegram_service.handle_command(chat_id, text, user_data)
    elsif contact.present?
      # Обработка отправленного контакта
      handle_contact_message(chat_id, contact, user_data)
    else
      handle_regular_message(chat_id, text, user_data)
    end
  end
  
  def process_callback_query(callback_query)
    chat_id = callback_query[:message][:chat][:id]
    data = callback_query[:data]
    callback_query_id = callback_query[:id]
    message_id = callback_query[:message][:message_id]
    
    Rails.logger.info "📞 Callback query: #{data} from #{chat_id}"
    
    # Проверяем, это callback для бронирования?
    if data.start_with?('booking_')
      # Загружаем данные пользователя из кэша
      user_data = Rails.cache.read("telegram_#{chat_id}_user_data") || {}
      telegram_service.handle_callback_query(chat_id, data, message_id, user_data)
      telegram_service.answer_callback_query(callback_query_id)
    else
      # Обычная логика настроек
    case data
    when 'settings'
      handle_settings_callback(chat_id, callback_query_id)
    when 'toggle_booking'
      toggle_notification_type(chat_id, 'booking', callback_query_id)
    when 'toggle_promotion'
      toggle_notification_type(chat_id, 'promotion', callback_query_id)
    when 'toggle_reminder'
      toggle_notification_type(chat_id, 'reminder', callback_query_id)
    when 'change_language'
      handle_language_callback(chat_id, callback_query_id)
    else
      telegram_service.answer_callback_query(callback_query_id, "Неизвестная команда")
      end
    end
  end
  
  def handle_regular_message(chat_id, text, user_data)
    # Проверяем, есть ли активная сессия бронирования
    session = TelegramBookingSession.active.find_by(chat_id: chat_id)
    
    if session
      # Обрабатываем ввод в рамках процесса бронирования
      telegram_service.handle_booking_step(chat_id, text, session)
    else
    # Базовая обработка обычных сообщений
    telegram_service.send_message(
      chat_id,
        "Дякую за повідомлення! Використовуйте /help для перегляду команд або /booking для створення бронювання."
    )
    end
  end

  def handle_contact_message(chat_id, contact, user_data)
    # Проверяем, есть ли активная сессия бронирования
    session = TelegramBookingSession.active.find_by(chat_id: chat_id)
    
    if session && session.current_step == 'phone_input'
      # Обрабатываем контакт как номер телефона
      phone = contact[:phone_number]
      telegram_service.handle_phone_input(chat_id, phone, session)
    else
      telegram_service.send_message(
        chat_id,
        "Дякую за контакт! Використовуйте /booking для створення бронювання."
      )
    end
  end
  
  def handle_settings_callback(chat_id, callback_query_id)
    subscription = TelegramSubscription.find_by(chat_id: chat_id)
    
    if subscription
      keyboard = {
        inline_keyboard: [
          [{ text: "🔔 Бронирования", callback_data: 'toggle_booking' }],
          [{ text: "🎉 Акции", callback_data: 'toggle_promotion' }],
          [{ text: "⏰ Напоминания", callback_data: 'toggle_reminder' }],
          [{ text: "🌍 Язык", callback_data: 'change_language' }]
        ]
      }
      
      message = "⚙️ Настройки уведомлений:\n\nВыберите тип уведомлений для настройки:"
      telegram_service.send_message(chat_id, message, keyboard)
    end
    
    telegram_service.answer_callback_query(callback_query_id)
  end
  
  def toggle_notification_type(chat_id, type, callback_query_id)
    subscription = TelegramSubscription.find_by(chat_id: chat_id)
    
    if subscription
      preferences = subscription.notification_preferences || {}
      current_state = preferences[type] != false # По умолчанию включено
      preferences[type] = !current_state
      subscription.update(notification_preferences: preferences)
      
      status = !current_state ? "включены" : "отключены"
      message = "#{type.humanize} уведомления #{status}"
      telegram_service.answer_callback_query(callback_query_id, message, true)
    end
  end
  
  def handle_language_callback(chat_id, callback_query_id)
    telegram_service.answer_callback_query(callback_query_id, "Смена языка будет добавлена в следующих версиях")
  end
  
  def telegram_service
    @telegram_service ||= TelegramService.new
  end
end 