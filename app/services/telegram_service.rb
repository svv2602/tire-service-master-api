class TelegramService
  include HTTParty
  
  base_uri 'https://api.telegram.org'
  
  def initialize
    @token = ENV['TELEGRAM_BOT_TOKEN']
    raise 'TELEGRAM_BOT_TOKEN не установлен' unless @token
  end

  # Отправка сообщения с поддержкой клавиатур
  def send_message(chat_id, message, keyboard = nil, parse_mode = 'HTML')
    Rails.logger.info "🚀 TelegramService: Отправляем сообщение в chat_id: #{chat_id}"
    Rails.logger.info "📝 TelegramService: Текст сообщения: #{message}"
    
    params = {
      chat_id: chat_id,
      text: message,
      parse_mode: parse_mode,
      disable_web_page_preview: true
    }
    
    # Добавляем inline клавиатуру если есть
    if keyboard.present?
      params[:reply_markup] = keyboard.to_json
    end
    
    Rails.logger.info "📦 TelegramService: Параметры запроса: #{params}"
    
    begin
      response = self.class.post("/bot#{@token}/sendMessage", body: params)
      Rails.logger.info "📡 TelegramService: Ответ от Telegram API: #{response.code} - #{response.body}"
      result = handle_response(response)
      Rails.logger.info "✅ TelegramService: Результат обработки: #{result}"
      result
    rescue => e
      Rails.logger.error "❌ TelegramService: Ошибка отправки: #{e.message}"
      Rails.logger.error "❌ TelegramService: Backtrace: #{e.backtrace.first(5).join('\n')}"
      raise e
    end
  end

  # Редактирование сообщения
  def edit_message(chat_id, message_id, text, keyboard = nil, parse_mode = 'HTML')
    Rails.logger.info "✏️ TelegramService: Редактируем сообщение #{message_id} в chat_id: #{chat_id}"
    
    params = {
      chat_id: chat_id,
      message_id: message_id,
      text: text,
      parse_mode: parse_mode,
      disable_web_page_preview: true
    }
    
    # Добавляем inline клавиатуру если есть
    if keyboard.present?
      params[:reply_markup] = keyboard.to_json
    end
    
    begin
      response = self.class.post("/bot#{@token}/editMessageText", body: params)
      Rails.logger.info "📡 TelegramService: Ответ от Telegram API (edit): #{response.code} - #{response.body}"
      handle_response(response)
    rescue => e
      Rails.logger.error "❌ TelegramService: Ошибка редактирования: #{e.message}"
      # Если не удалось отредактировать, отправляем новое сообщение
      send_message(chat_id, text, keyboard, parse_mode)
    end
  end

  # Ответ на callback query
  def answer_callback_query(callback_query_id, text = nil, show_alert = false)
    params = {
      callback_query_id: callback_query_id,
      text: text,
      show_alert: show_alert
    }
    
    response = self.class.post("/bot#{@token}/answerCallbackQuery", body: params)
    handle_response(response)
  end

  # Получение информации о боте
  def get_me
    response = self.class.get("/bot#{@token}/getMe")
    handle_response(response)
  end

  # Получение информации о пользователе
  def get_chat(chat_id)
    response = self.class.get("/bot#{@token}/getChat", query: { chat_id: chat_id })
    handle_response(response)
  end

  # Получение обновлений (для webhook)
  def get_updates(offset = 0)
    response = self.class.get("/bot#{@token}/getUpdates", query: { offset: offset })
    handle_response(response)
  end

  # Установка webhook
  def set_webhook(url)
    params = {
      url: url,
      allowed_updates: ['message', 'callback_query']
    }
    
    response = self.class.post("/bot#{@token}/setWebhook", body: params)
    handle_response(response)
  end

  # Удаление webhook
  def delete_webhook
    response = self.class.post("/bot#{@token}/deleteWebhook")
    handle_response(response)
  end

  # Получение информации о webhook
  def get_webhook_info
    response = self.class.get("/bot#{@token}/getWebhookInfo")
    handle_response(response)
  end

  # Отправка уведомления с сохранением в БД
  def send_notification(user, message, options = {})
    return false unless user.telegram_subscription&.can_receive_notifications?

    subscription = user.telegram_subscription
    return false unless subscription

    # Создаем запись уведомления
    notification = TelegramNotification.create!(
      user: user,
      message: message,
      chat_id: subscription.chat_id,
      notification_type: options[:type] || 'general',
      booking: options[:booking]
    )

    begin
      # Отправляем сообщение
      response = send_message(subscription.chat_id, message, options[:keyboard])
      
      if response[:ok]
        notification.mark_as_sent!(response, response[:result][:message_id])
        subscription.update_last_interaction!
        
        Rails.logger.info "Telegram сповіщення надіслано користувачу #{user.id}"
        true
      else
        notification.mark_as_failed!(response[:description])
        
        Rails.logger.error "Помилка відправки Telegram сповіщення: #{response[:description]}"
        false
      end
    rescue => e
      notification.mark_as_failed!(e.message)
      Rails.logger.error "Виняток при відправці Telegram сповіщення: #{e.message}"
      false
    end
  end

  # Массовая отправка уведомлений
  def send_bulk_notification(users, message, options = {})
    results = {
      total: users.count,
      sent: 0,
      failed: 0,
      details: []
    }

    users.each do |user|
      begin
        if send_notification(user, message, options)
          results[:sent] += 1
          results[:details] << { user_id: user.id, status: 'sent' }
        else
          results[:failed] += 1
          results[:details] << { user_id: user.id, status: 'failed', error: 'Не вдалося надіслати' }
        end
      rescue => e
        results[:failed] += 1
        results[:details] << { user_id: user.id, status: 'failed', error: e.message }
      end
    end

    Rails.logger.info "Масова розсилка завершена: #{results[:sent]} надіслано, #{results[:failed]} помилок"
    results
  end

  # Повторная отправка неудачных уведомлений
  def retry_failed_notifications
    failed_notifications = TelegramNotification.failed.where('created_at > ?', 24.hours.ago)
    retried_count = 0

    failed_notifications.each do |notification|
      if notification.can_retry?
        if send_notification(notification.user, notification.message, { 
          type: notification.notification_type,
          booking: notification.booking 
        })
          retried_count += 1
        end
      end
    end

    Rails.logger.info "Повторно надіслано #{retried_count} сповіщень"
    retried_count
  end

  # Обработка команд бота
  def handle_command(chat_id, command, user_data = {})
    case command
    when '/start'
      handle_start_command(chat_id, user_data)
    when '/stop'
      handle_stop_command(chat_id)
    when '/help'
      handle_help_command(chat_id)
    when '/status'
      handle_status_command(chat_id)
    when '/settings'
      handle_settings_command(chat_id)
    else
      send_message(chat_id, "❓ Неизвестная команда. Используйте /help для получения списка команд.")
    end
  end

  # Форматирование уведомления о бронировании
  def format_booking_notification(booking, type)
    service_name = booking.service_point_service&.service&.name || 'Невідома послуга'
    point_name = booking.service_point&.name || 'Невідома точка'
    date = booking.start_time&.strftime('%d.%m.%Y о %H:%M') || 'Не вказано'

    case type
    when 'booking_created'
      "🎉 <b>Нове бронювання створено!</b>\n\n" \
      "🔧 <b>Послуга:</b> #{service_name}\n" \
      "📍 <b>Сервісна точка:</b> #{point_name}\n" \
      "📅 <b>Дата та час:</b> #{date}\n\n" \
      "Ми зв'яжемося з вами для підтвердження."
    when 'booking_confirmed'
      "✅ <b>Бронювання підтверджено!</b>\n\n" \
      "🔧 <b>Послуга:</b> #{service_name}\n" \
      "📍 <b>Сервісна точка:</b> #{point_name}\n" \
      "📅 <b>Дата та час:</b> #{date}\n\n" \
      "Очікуємо на вас у призначений час!"
    when 'booking_reminder'
      "⏰ <b>Нагадування про візит</b>\n\n" \
      "Завтра у вас заплановано:\n" \
      "🔧 <b>Послуга:</b> #{service_name}\n" \
      "📍 <b>Сервісна точка:</b> #{point_name}\n" \
      "📅 <b>Час:</b> #{date}\n\n" \
      "Не забудьте прийти вчасно!"
    when 'booking_cancelled'
      "❌ <b>Бронювання скасовано</b>\n\n" \
      "🔧 <b>Послуга:</b> #{service_name}\n" \
      "📍 <b>Сервісна точка:</b> #{point_name}\n" \
      "📅 <b>Дата та час:</b> #{date}\n\n" \
      "Ви можете створити нове бронювання на сайті."
    when 'booking_completed'
      "✅ <b>Послуга виконана!</b>\n\n" \
      "🔧 <b>Послуга:</b> #{service_name}\n" \
      "📍 <b>Сервісна точка:</b> #{point_name}\n" \
      "📅 <b>Дата:</b> #{date}\n\n" \
      "Дякуємо за вибір Tire Service! 🚗"
    else
      "📋 <b>Оновлення бронювання</b>\n\n" \
      "🔧 <b>Послуга:</b> #{service_name}\n" \
      "📍 <b>Сервісна точка:</b> #{point_name}\n" \
      "📅 <b>Дата та час:</b> #{date}"
    end
  end

  private

  def handle_response(response)
    if response.success?
      JSON.parse(response.body, symbolize_names: true)
    else
      {
        ok: false,
        error_code: response.code,
        description: response.message
      }
    end
  rescue JSON::ParserError => e
    {
      ok: false,
      error_code: 'parse_error',
      description: "Помилка парсингу відповіді: #{e.message}"
    }
  end

  def handle_start_command(chat_id, user_data)
    message = "🚗 Вітаємо в Tire Service!\n\n" \
              "Я надсилатиму вам сповіщення про:\n" \
              "• Статус ваших бронювань\n" \
              "• Нагадування про майбутні візити\n" \
              "• Спеціальні пропозиції\n\n" \
              "Для налаштування сповіщень використовуйте /settings\n" \
              "Для відключення сповіщень використовуйте /stop"
    
    keyboard = {
      inline_keyboard: [
        [{ text: "🌐 Відкрити сайт", url: ENV['FRONTEND_URL'] || 'http://localhost:3008' }],
        [{ text: "⚙️ Налаштування", callback_data: 'settings' }]
      ]
    }
    
    send_message(chat_id, message, keyboard)
  end

  def handle_stop_command(chat_id)
    # Деактивируем подписку
    subscription = TelegramSubscription.find_by(chat_id: chat_id)
    if subscription
      subscription.deactivate!
      message = "🔕 Сповіщення відключено.\n\nДля повторного включення використовуйте /start"
    else
      message = "❓ Підписка не знайдена."
    end
    
    send_message(chat_id, message)
  end

  def handle_help_command(chat_id)
    message = "📋 Доступні команди:\n\n" \
              "/start - Включити сповіщення\n" \
              "/stop - Відключити сповіщення\n" \
              "/status - Статус підписки\n" \
              "/settings - Налаштування сповіщень\n" \
              "/help - Ця довідка\n\n" \
              "🌐 Сайт: #{ENV['FRONTEND_URL'] || 'http://localhost:3008'}"
    
    send_message(chat_id, message)
  end

  def handle_status_command(chat_id)
    subscription = TelegramSubscription.find_by(chat_id: chat_id)
    
    if subscription
      user = subscription.user
      message = "📊 Статус підписки:\n\n" \
                "👤 Користувач: #{user.full_name}\n" \
                "📧 Email: #{user.email}\n" \
                "🔔 Статус: #{subscription.is_active? ? '✅ Активна' : '❌ Неактивна'}\n" \
                "🌍 Мова: Українська\n" \
                "📱 Сповіщень надіслано: #{subscription.sent_notifications_count}\n" \
                "📈 Успішність доставки: #{subscription.success_rate}%"
    else
      message = "❓ Підписка не знайдена. Використовуйте /start для підключення."
    end
    
    send_message(chat_id, message)
  end

  def handle_settings_command(chat_id)
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
      send_message(chat_id, message, keyboard)
    else
      message = "❓ Подписка не найдена. Используйте /start для подключения."
      send_message(chat_id, message)
    end
  end
end 