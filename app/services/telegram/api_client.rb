# frozen_string_literal: true

require 'httparty'

module Telegram
  # APIClient - работа с Telegram Bot API
  # Отвечает за: HTTP запросы, отправка сообщений, webhook
  class APIClient
    include HTTParty
    base_uri 'https://api.telegram.org'

    class APIError < StandardError; end
    class TokenMissingError < StandardError; end

    attr_reader :token

    def initialize(token = nil)
      @token = token || fetch_token
      raise TokenMissingError, 'TELEGRAM_BOT_TOKEN не установлен' unless @token.present?

      Rails.logger.info "✅ Telegram::APIClient инициализирован с токеном: #{@token[0..10]}..."
    end

    # === Отправка сообщений ===

    def send_message(chat_id, text, keyboard: nil, parse_mode: 'HTML')
      Rails.logger.info "🚀 Telegram::APIClient: Отправляем сообщение в chat_id: #{chat_id}"

      params = {
        chat_id: chat_id,
        text: text,
        parse_mode: parse_mode,
        disable_web_page_preview: true
      }
      params[:reply_markup] = keyboard.to_json if keyboard.present?

      post_request('sendMessage', params)
    end

    def edit_message(chat_id, message_id, text, keyboard: nil, parse_mode: 'HTML')
      Rails.logger.info "✏️ Telegram::APIClient: Редактируем сообщение #{message_id}"

      params = {
        chat_id: chat_id,
        message_id: message_id,
        text: text,
        parse_mode: parse_mode,
        disable_web_page_preview: true
      }
      params[:reply_markup] = keyboard.to_json if keyboard.present?

      post_request('editMessageText', params)
    rescue StandardError => e
      Rails.logger.error "❌ Telegram::APIClient: Ошибка редактирования: #{e.message}"
      # Fallback: отправляем новое сообщение
      send_message(chat_id, text, keyboard: keyboard, parse_mode: parse_mode)
    end

    def answer_callback_query(callback_query_id, text: nil, show_alert: false)
      params = { callback_query_id: callback_query_id }
      params[:text] = text if text.present?
      params[:show_alert] = show_alert if show_alert

      post_request('answerCallbackQuery', params)
    end

    # === Информация ===

    def get_me
      get_request('getMe')
    end

    def get_chat(chat_id)
      get_request('getChat', chat_id: chat_id)
    end

    def get_updates(offset: nil)
      params = {}
      params[:offset] = offset if offset
      get_request('getUpdates', params)
    end

    # === Webhook ===

    def set_webhook(webhook_url)
      Rails.logger.info "🔗 Устанавливаем webhook: #{webhook_url}"

      result = post_request('setWebhook', url: webhook_url)

      if result[:ok]
        Rails.logger.info '✅ Webhook успешно установлен'
      else
        Rails.logger.error "❌ Ошибка установки webhook: #{result[:description]}"
      end

      result
    end

    def delete_webhook
      Rails.logger.info '🗑️ Удаляем webhook'

      result = post_request('deleteWebhook')

      if result[:ok]
        Rails.logger.info '✅ Webhook успешно удален'
      else
        Rails.logger.error "❌ Ошибка удаления webhook: #{result[:description]}"
      end

      result
    end

    def get_webhook_info
      get_request('getWebhookInfo')
    end

    private

    def fetch_token
      settings = TelegramSetting.current
      settings.effective_bot_token
    end

    def post_request(method, params = {})
      Rails.logger.info "📦 Telegram::APIClient: POST /#{method}"

      response = self.class.post("/bot#{@token}/#{method}", body: params)
      Rails.logger.info "📡 Telegram::APIClient: Ответ: #{response.code}"

      handle_response(response)
    rescue StandardError => e
      Rails.logger.error "❌ Telegram::APIClient: Ошибка: #{e.message}"
      raise APIError, e.message
    end

    def get_request(method, params = {})
      response = self.class.get("/bot#{@token}/#{method}", query: params)
      handle_response(response)
    rescue StandardError => e
      Rails.logger.error "❌ Telegram::APIClient: Ошибка GET: #{e.message}"
      raise APIError, e.message
    end

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
        description: "Ошибка парсинга: #{e.message}"
      }
    end
  end
end
