class Api::V1::NotificationChannelSettingsController < ApplicationController
  before_action :authenticate_request
  before_action :ensure_admin
  before_action :set_channel_setting, only: [:show, :update]

  # GET /api/v1/notification_channel_settings
  def index
    @settings = NotificationChannelSetting.by_priority
    
    render json: {
      settings: ActiveModel::Serializer::CollectionSerializer.new(
        @settings,
        serializer: NotificationChannelSettingSerializer
      ),
      statistics: notification_statistics,
      summary: {
        total_channels: @settings.count,
        enabled_channels: @settings.enabled.count,
        disabled_channels: @settings.disabled.count
      }
    }
  end

  # GET /api/v1/notification_channel_settings/:channel_type
  def show
    render json: @setting, serializer: NotificationChannelSettingSerializer
  end

  # PATCH/PUT /api/v1/notification_channel_settings/:channel_type
  def update
    if @setting.update(channel_setting_params)
      render json: {
        setting: NotificationChannelSettingSerializer.new(@setting),
        message: "Настройки канала #{@setting.channel_name} успешно обновлены"
      }
    else
      render json: {
        errors: @setting.errors.full_messages,
        message: "Ошибка при обновлении настроек канала"
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/notification_channel_settings/bulk_update
  def bulk_update
    settings_params = params.require(:settings)
    updated_settings = []
    errors = []

    settings_params.each do |channel_type, settings|
      setting = NotificationChannelSetting.for_channel(channel_type)
      
      if setting&.update(settings.permit(:enabled, :priority, :retry_attempts, :retry_delay, :daily_limit, :rate_limit_per_minute))
        updated_settings << setting
      else
        errors << "#{channel_type}: #{setting&.errors&.full_messages&.join(', ') || 'не найден'}"
      end
    end

    if errors.empty?
      render json: {
        settings: ActiveModel::Serializer::CollectionSerializer.new(
          updated_settings,
          serializer: NotificationChannelSettingSerializer
        ),
        message: "Настройки всех каналов успешно обновлены"
      }
    else
      render json: {
        errors: errors,
        message: "Ошибки при обновлении настроек"
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/notification_channel_settings/statistics
  def statistics
    render json: {
      statistics: notification_statistics,
      performance: channel_performance_metrics
    }
  end

  private

  def set_channel_setting
    channel_type = params[:id] || params[:channel_type]
    @setting = NotificationChannelSetting.for_channel(channel_type)
    
    unless @setting
      render json: {
        error: "Настройки для канала '#{channel_type}' не найдены"
      }, status: :not_found
    end
  end

  def channel_setting_params
    params.require(:notification_channel_setting).permit(
      :enabled, :priority, :retry_attempts, :retry_delay,
      :daily_limit, :rate_limit_per_minute
    )
  end

  def ensure_admin
    unless current_user&.admin? || current_user&.partner?
      render json: { error: 'Доступ запрещен' }, status: :forbidden
    end
  end

  # Статистика уведомлений (интеграция с существующими системами)
  def notification_statistics
    {
      email: email_statistics,
      push: push_statistics,
      telegram: telegram_statistics
    }
  end

  def email_statistics
    # Используем реальную статистику из notification_logs и notifications
    email_logs = NotificationLog.email_notifications.where(created_at: 30.days.ago..Time.current)
    email_notifications = Notification.where(send_via: 'email', created_at: 30.days.ago..Time.current)
    
    sent_count = email_logs.sent.count + email_notifications.sent.count
    delivered_count = email_logs.delivered.count
    failed_count = email_logs.failed.count
    bounced_count = email_logs.where(status: 'bounced').count
    
    delivery_rate = sent_count > 0 ? (delivered_count.to_f / sent_count * 100).round(2) : 0.0
    
    {
      sent: sent_count,
      delivered: delivered_count,
      failed: failed_count,
      bounced: bounced_count,
      delivery_rate: delivery_rate
    }
  end

  def push_statistics
    # Используем статистику push уведомлений
    push_logs = NotificationLog.where(notification_type: 'push', created_at: 30.days.ago..Time.current)
    push_notifications = Notification.where(send_via: 'push', created_at: 30.days.ago..Time.current)
    
    sent_count = push_logs.sent.count + push_notifications.sent.count
    delivered_count = push_logs.delivered.count
    failed_count = push_logs.failed.count
    clicked_count = push_logs.clicked.count
    
    delivery_rate = sent_count > 0 ? (delivered_count.to_f / sent_count * 100).round(2) : 0.0
    
    {
      sent: sent_count,
      delivered: delivered_count,
      failed: failed_count,
      clicked: clicked_count,
      delivery_rate: delivery_rate
    }
  end

  def telegram_statistics
    # Используем реальную статистику Telegram
    telegram_logs = NotificationLog.telegram_notifications.where(created_at: 30.days.ago..Time.current)
    telegram_notifications = TelegramNotification.where(created_at: 30.days.ago..Time.current)
    telegram_subscriptions_count = TelegramSubscription.active.count rescue 0
    
    sent_count = telegram_logs.sent.count + telegram_notifications.sent.count
    delivered_count = telegram_logs.delivered.count + telegram_notifications.sent.count
    failed_count = telegram_logs.failed.count + telegram_notifications.failed.count
    read_count = telegram_logs.opened.count
    
    delivery_rate = sent_count > 0 ? (delivered_count.to_f / sent_count * 100).round(2) : 0.0
    
    {
      sent: sent_count,
      delivered: delivered_count,
      failed: failed_count,
      read: read_count,
      delivery_rate: delivery_rate,
      active_subscribers: telegram_subscriptions_count
    }
  end

  def channel_performance_metrics
    # Реальные метрики производительности за последние 24 часа
    last_24h_start = 24.hours.ago
    
    email_24h = NotificationLog.email_notifications.where(created_at: last_24h_start..Time.current)
    push_24h = NotificationLog.where(notification_type: 'push', created_at: last_24h_start..Time.current)
    telegram_24h = TelegramNotification.where(created_at: last_24h_start..Time.current)
    
    {
      last_24h: {
        email: { 
          sent: email_24h.sent.count, 
          delivered: email_24h.delivered.count, 
          failed: email_24h.failed.count 
        },
        push: { 
          sent: push_24h.sent.count, 
          delivered: push_24h.delivered.count, 
          failed: push_24h.failed.count 
        },
        telegram: { 
          sent: telegram_24h.sent.count, 
          delivered: telegram_24h.sent.count, 
          failed: telegram_24h.failed.count 
        }
      },
      success_rates: {
        email: email_24h.count > 0 ? (email_24h.delivered.count.to_f / email_24h.count * 100).round(2) : 0.0,
        push: push_24h.count > 0 ? (push_24h.delivered.count.to_f / push_24h.count * 100).round(2) : 0.0,
        telegram: telegram_24h.count > 0 ? (telegram_24h.sent.count.to_f / telegram_24h.count * 100).round(2) : 0.0
      },
      total_active_subscribers: TelegramSubscription.active.count + PushSubscription.where(is_active: true).count
    }
  end
end 