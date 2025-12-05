# frozen_string_literal: true

module Telegram
  # Service - главный оркестратор Telegram бота
  # Отвечает за: координацию модулей, уведомления, массовые рассылки
  class Service
    attr_reader :api_client, :formatter, :booking_flow, :command_handler

    def initialize(api_client: nil, formatter: nil, booking_flow: nil, command_handler: nil)
      @api_client = api_client || APIClient.new
      @formatter = formatter || MessageFormatter.new
      @booking_flow = booking_flow || BookingFlow.new(api_client: @api_client, formatter: @formatter)
      @command_handler = command_handler || CommandHandler.new(
        api_client: @api_client,
        formatter: @formatter,
        booking_flow: @booking_flow
      )
    end

    # === Делегирование API методов ===

    def send_message(chat_id, message, keyboard = nil, parse_mode = 'HTML')
      api_client.send_message(chat_id, message, keyboard: keyboard, parse_mode: parse_mode)
    end

    def edit_message(chat_id, message_id, text, keyboard = nil, parse_mode = 'HTML')
      api_client.edit_message(chat_id, message_id, text, keyboard: keyboard, parse_mode: parse_mode)
    end

    def answer_callback_query(callback_query_id, text = nil, show_alert = false)
      api_client.answer_callback_query(callback_query_id, text: text, show_alert: show_alert)
    end

    def get_me
      api_client.get_me
    end

    def get_chat(chat_id)
      api_client.get_chat(chat_id)
    end

    def get_updates(offset = nil)
      api_client.get_updates(offset: offset)
    end

    def set_webhook(webhook_url)
      api_client.set_webhook(webhook_url)
    end

    def delete_webhook
      api_client.delete_webhook
    end

    def get_webhook_info
      api_client.get_webhook_info
    end

    # === Делегирование команд ===

    def handle_command(chat_id, command, user_data = {})
      command_handler.handle_command(chat_id, command, user_data)
    end

    def handle_callback_query(chat_id, callback_data, message_id = nil, user_data = {})
      command_handler.handle_callback_query(chat_id, callback_data, message_id, user_data)
    end

    # === Делегирование бронирования ===

    def handle_booking_command(chat_id)
      booking_flow.start_booking(chat_id)
    end

    # === Уведомления ===

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
        response = api_client.send_message(subscription.chat_id, message, keyboard: options[:keyboard])

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
      rescue StandardError => e
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
        if send_notification(user, message, options)
          results[:sent] += 1
          results[:details] << { user_id: user.id, status: 'sent' }
        else
          results[:failed] += 1
          results[:details] << { user_id: user.id, status: 'failed', error: 'Не вдалося надіслати' }
        end
      rescue StandardError => e
        results[:failed] += 1
        results[:details] << { user_id: user.id, status: 'failed', error: e.message }
      end

      Rails.logger.info "Масова розсилка завершена: #{results[:sent]} надіслано, #{results[:failed]} помилок"
      results
    end

    # Повторная отправка неудачных уведомлений
    def retry_failed_notifications
      failed_notifications = TelegramNotification.failed.where('created_at > ?', 24.hours.ago)
      retried_count = 0

      failed_notifications.each do |notification|
        next unless notification.can_retry?

        if send_notification(notification.user, notification.message, {
          type: notification.notification_type,
          booking: notification.booking
        })
          retried_count += 1
        end
      end

      Rails.logger.info "Повторно надіслано #{retried_count} сповіщень"
      retried_count
    end

    # === Форматирование ===

    def format_booking_notification(booking, type, language = 'uk')
      formatter.format_booking_notification(booking, type, language)
    end
  end
end
