class Api::V1::TelegramSettingsController < ApplicationController
  before_action :authenticate_request
  before_action :set_telegram_settings, only: [:show, :update, :test_connection, :test_message]

  # GET /api/v1/telegram_settings
  def show
    authorize TelegramSetting, :show?
    
    render json: {
      telegram_settings: format_settings(@telegram_settings),
      statistics: get_telegram_statistics
    }
  end

  # PATCH/PUT /api/v1/telegram_settings
  def update
    authorize TelegramSetting, :update?
    
    if @telegram_settings.update(telegram_settings_params)
      render json: {
        message: 'Настройки Telegram успешно обновлены',
        telegram_settings: format_settings(@telegram_settings)
      }
    else
      render json: {
        errors: @telegram_settings.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/telegram_settings/test_connection
  def test_connection
    authorize TelegramSetting, :update?
    
    begin
      telegram_service = TelegramService.new
      bot_info = telegram_service.get_me
      
      if bot_info[:ok]
        render json: {
          success: true,
          message: 'Подключение к Telegram API успешно',
          bot_info: {
            id: bot_info[:result][:id],
            first_name: bot_info[:result][:first_name],
            username: bot_info[:result][:username],
            can_join_groups: bot_info[:result][:can_join_groups],
            can_read_all_group_messages: bot_info[:result][:can_read_all_group_messages],
            supports_inline_queries: bot_info[:result][:supports_inline_queries]
          }
        }
      else
        render json: {
          success: false,
          message: "Ошибка подключения: #{bot_info[:description]}"
        }, status: :unprocessable_entity
      end
      
    rescue => e
      render json: {
        success: false,
        message: "Исключение при подключении: #{e.message}"
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/telegram_settings/test_message
  def test_message
    authorize TelegramSetting, :update?
    
    chat_id = params[:chat_id] || @telegram_settings.effective_admin_chat_id
    
    unless chat_id.present?
      render json: {
        success: false,
        message: 'Chat ID не указан'
      }, status: :unprocessable_entity
      return
    end
    
    begin
      telegram_service = TelegramService.new
      test_message = "🧪 <b>Тестовое сообщение</b>\n\n" \
                     "✅ Telegram бот работает корректно!\n" \
                     "📅 Время: #{Time.current.strftime('%d.%m.%Y %H:%M')}\n\n" \
                     "🤖 Система уведомлений готова к работе."
      
      response = telegram_service.send_message(chat_id, test_message)
      
      if response[:ok]
        render json: {
          success: true,
          message: 'Тестовое сообщение отправлено успешно',
          message_id: response[:result][:message_id]
        }
      else
        render json: {
          success: false,
          message: "Ошибка отправки: #{response[:description]}"
        }, status: :unprocessable_entity
      end
      
    rescue => e
      render json: {
        success: false,
        message: "Исключение при отправке: #{e.message}"
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/telegram_settings/set_webhook
  def set_webhook
    authorize TelegramSetting, :update?
    
    webhook_url = params[:webhook_url] || @telegram_settings.effective_webhook_url
    
    unless webhook_url.present?
      render json: {
        success: false,
        message: 'Webhook URL не указан'
      }, status: :unprocessable_entity
      return
    end
    
    begin
      telegram_service = TelegramService.new
      response = telegram_service.set_webhook(webhook_url)
      
      if response[:ok]
        # Обновляем URL в настройках если он изменился
        if @telegram_settings.webhook_url != webhook_url
          @telegram_settings.update(webhook_url: webhook_url)
        end
        
        render json: {
          success: true,
          message: 'Webhook успешно установлен',
          webhook_url: webhook_url
        }
      else
        render json: {
          success: false,
          message: "Ошибка установки webhook: #{response[:description]}"
        }, status: :unprocessable_entity
      end
      
    rescue => e
      render json: {
        success: false,
        message: "Исключение при установке webhook: #{e.message}"
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/telegram_settings/webhook_info
  def webhook_info
    authorize TelegramSetting, :show?
    
    begin
      telegram_service = TelegramService.new
      webhook_info = telegram_service.get_webhook_info
      
      if webhook_info[:ok]
        render json: {
          success: true,
          webhook_info: webhook_info[:result]
        }
      else
        render json: {
          success: false,
          message: "Ошибка получения информации о webhook: #{webhook_info[:description]}"
        }, status: :unprocessable_entity
      end
      
    rescue => e
      render json: {
        success: false,
        message: "Исключение при получении информации о webhook: #{e.message}"
      }, status: :unprocessable_entity
    end
  end

  private

  def set_telegram_settings
    @telegram_settings = TelegramSetting.current
  end

  def telegram_settings_params
    permitted_params = params.require(:telegram_settings).permit(
      :bot_token, :bot_username, :webhook_url, :admin_chat_id, 
      :enabled, :test_mode, :auto_subscription
    )
    
    # Преобразуем пустые строки в nil для полей, которые могут быть пустыми
    [:bot_token, :webhook_url, :admin_chat_id].each do |field|
      if permitted_params[field].present? && permitted_params[field].strip.empty?
        permitted_params[field] = nil
      end
    end
    
    permitted_params
  end

  def format_settings(settings)
    {
      id: settings.id,
      bot_token: settings.bot_token.present? ? "#{settings.bot_token[0..10]}..." : nil,
      bot_username: settings.bot_username,
      webhook_url: settings.webhook_url,
      admin_chat_id: settings.admin_chat_id,
      enabled: settings.enabled,
      test_mode: settings.test_mode,
      auto_subscription: settings.auto_subscription,
      system_status: settings.system_status,
      status_color: settings.status_color,
      status_text: settings.status_text,
      ready_for_production: settings.ready_for_production?,
      valid_configuration: settings.valid_configuration?,
      created_at: settings.created_at,
      updated_at: settings.updated_at
    }
  end

  def get_telegram_statistics
    {
      total_subscriptions: TelegramSubscription.count,
      active_subscriptions: TelegramSubscription.active_subscriptions.count,
      total_notifications: TelegramNotification.count,
      sent_notifications: TelegramNotification.sent.count,
      failed_notifications: TelegramNotification.failed.count,
      success_rate: calculate_success_rate
    }
  end

  def calculate_success_rate
    total = TelegramNotification.count
    return 0 if total.zero?
    
    successful = TelegramNotification.sent.count
    (successful.to_f / total * 100).round(1)
  end
end 