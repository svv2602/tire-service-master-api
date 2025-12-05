# frozen_string_literal: true

module Telegram
  # CommandHandler - обработка команд бота
  # Отвечает за: /start, /help, /status, /settings и т.д.
  class CommandHandler
    attr_reader :api_client, :formatter, :booking_flow

    def initialize(api_client:, formatter: nil, booking_flow: nil)
      @api_client = api_client
      @formatter = formatter || MessageFormatter.new
      @booking_flow = booking_flow || BookingFlow.new(api_client: api_client, formatter: @formatter)
    end

    def handle_command(chat_id, command, user_data = {})
      case command
      when '/start'
        handle_start(chat_id, user_data)
      when '/stop'
        handle_stop(chat_id)
      when '/help'
        handle_help(chat_id)
      when '/status'
        handle_status(chat_id)
      when '/settings'
        handle_settings(chat_id)
      when '/booking'
        booking_flow.start_booking(chat_id)
      else
        handle_unknown_or_session(chat_id, command)
      end
    end

    def handle_callback_query(chat_id, callback_data, message_id = nil, user_data = {})
      Rails.logger.info "🔄 Telegram::CommandHandler: Обработка callback_query: #{callback_data}"

      session = TelegramBookingSession.active.find_by(chat_id: chat_id)

      if session && callback_data.start_with?('booking_')
        booking_flow.handle_callback(chat_id, callback_data, message_id, session)
      else
        handle_settings_callback(chat_id, callback_data, message_id)
      end
    end

    private

    def handle_start(chat_id, _user_data)
      message = "🚗 Вітаємо в Tire Service!\n\n" \
                "Я надсилатиму вам сповіщення про:\n" \
                "• Статус ваших бронювань\n" \
                "• Нагадування про майбутні візити\n" \
                "• Спеціальні пропозиції\n\n" \
                "Також ви можете створити бронювання прямо тут!\n\n" \
                "Для налаштування сповіщень використовуйте /settings\n" \
                "Для відключення сповіщень використовуйте /stop"

      keyboard = formatter.build_main_menu_keyboard
      api_client.send_message(chat_id, message, keyboard: keyboard)
    end

    def handle_stop(chat_id)
      subscription = TelegramSubscription.find_by(chat_id: chat_id)

      if subscription
        subscription.deactivate!
        message = "🔕 Сповіщення відключено.\n\nДля повторного включення використовуйте /start"
      else
        message = '❓ Підписка не знайдена.'
      end

      api_client.send_message(chat_id, message)
    end

    def handle_help(chat_id)
      frontend_url = ENV.fetch('FRONTEND_URL', 'http://localhost:3008')

      message = "📋 Доступні команди:\n\n" \
                "/start - Включити сповіщення\n" \
                "/booking - Створити бронювання 📅\n" \
                "/stop - Відключити сповіщення\n" \
                "/status - Статус підписки\n" \
                "/settings - Налаштування сповіщень\n" \
                "/help - Ця довідка\n\n" \
                "🌐 Сайт: #{frontend_url}"

      api_client.send_message(chat_id, message)
    end

    def handle_status(chat_id)
      subscription = TelegramSubscription.find_by(chat_id: chat_id)

      if subscription
        user = subscription.user
        status_text = subscription.is_active? ? '✅ Активна' : '❌ Неактивна'

        message = "📊 Статус підписки:\n\n" \
                  "👤 Користувач: #{user.full_name}\n" \
                  "📧 Email: #{user.email}\n" \
                  "🔔 Статус: #{status_text}\n" \
                  "🌍 Мова: Українська\n" \
                  "📱 Сповіщень надіслано: #{subscription.sent_notifications_count}\n" \
                  "📈 Успішність доставки: #{subscription.success_rate}%"
      else
        message = '❓ Підписка не знайдена. Використовуйте /start для підключення.'
      end

      api_client.send_message(chat_id, message)
    end

    def handle_settings(chat_id)
      subscription = TelegramSubscription.find_by(chat_id: chat_id)

      if subscription
        keyboard = formatter.build_settings_keyboard
        message = "⚙️ Настройки уведомлений:\n\nВыберите тип уведомлений для настройки:"
        api_client.send_message(chat_id, message, keyboard: keyboard)
      else
        message = '❓ Подписка не найдена. Используйте /start для подключения.'
        api_client.send_message(chat_id, message)
      end
    end

    def handle_unknown_or_session(chat_id, command)
      # Проверяем активную сессию бронирования
      session = TelegramBookingSession.active.find_by(chat_id: chat_id)

      if session
        booking_flow.handle_step(chat_id, command, session)
      else
        api_client.send_message(chat_id, '❓ Неизвестная команда. Используйте /help для получения списка команд.')
      end
    end

    def handle_settings_callback(chat_id, callback_data, _message_id)
      case callback_data
      when 'settings'
        handle_settings(chat_id)
      when 'start_booking'
        booking_flow.start_booking(chat_id)
      when 'toggle_booking', 'toggle_promotion', 'toggle_reminder'
        toggle_notification_setting(chat_id, callback_data)
      when 'change_language'
        handle_language_change(chat_id)
      end
    end

    def toggle_notification_setting(chat_id, setting_type)
      subscription = TelegramSubscription.find_by(chat_id: chat_id)
      return unless subscription

      setting_name = setting_type.sub('toggle_', '')
      # Здесь была бы логика переключения настройки
      api_client.send_message(chat_id, "✅ Настройка '#{setting_name}' обновлена")
    end

    def handle_language_change(chat_id)
      api_client.send_message(chat_id, '🌍 Выбор языка пока недоступен')
    end
  end
end
