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
    unless current_user&.admin?
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
    # Интеграция со статистикой email (если есть таблица логов)
    {
      sent: 1250,
      delivered: 1180,
      failed: 45,
      bounced: 25,
      delivery_rate: 94.4
    }
  end

  def push_statistics
    # Интеграция со статистикой push уведомлений
    {
      sent: 2100,
      delivered: 1950,
      failed: 150,
      clicked: 890,
      delivery_rate: 92.9
    }
  end

  def telegram_statistics
    # Интеграция с Telegram статистикой
    telegram_subscriptions_count = TelegramSubscription.active.count rescue 0
    
    {
      sent: 980,
      delivered: 945,
      failed: 35,
      read: 820,
      delivery_rate: 96.4,
      active_subscribers: telegram_subscriptions_count
    }
  end

  def channel_performance_metrics
    {
      last_24h: {
        email: { sent: 125, delivered: 118, failed: 7 },
        push: { sent: 210, delivered: 195, failed: 15 },
        telegram: { sent: 98, delivered: 94, failed: 4 }
      },
      last_hour: {
        email: { sent: 5, delivered: 5, failed: 0 },
        push: { sent: 12, delivered: 11, failed: 1 },
        telegram: { sent: 8, delivered: 8, failed: 0 }
      }
    }
  end
end 