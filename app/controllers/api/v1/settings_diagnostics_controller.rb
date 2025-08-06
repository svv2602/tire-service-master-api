# frozen_string_literal: true

# Контроллер для диагностики настроек системы
class Api::V1::SettingsDiagnosticsController < ApplicationController
  before_action :authenticate_request
  before_action :ensure_admin

  # GET /api/v1/settings_diagnostics
  def index
    diagnostics = {
      system_settings: diagnose_system_settings,
      email_settings: diagnose_email_settings,
      push_settings: diagnose_push_settings,
      telegram_settings: diagnose_telegram_settings,
      google_oauth_settings: diagnose_google_oauth_settings,
      notification_channels: diagnose_notification_channels,
      overall_status: calculate_overall_status
    }

    render json: {
      diagnostics: diagnostics,
      generated_at: Time.current,
      server_time: Time.current.strftime('%d.%m.%Y %H:%M:%S')
    }
  end

  private

  # Диагностика системных настроек
  def diagnose_system_settings
    settings = SystemSetting.all.group_by(&:category)
    
    {
      status: settings.any? ? 'configured' : 'not_configured',
      total_settings: SystemSetting.count,
      categories: settings.keys,
      categories_count: settings.keys.count,
      configured_settings: SystemSetting.where.not(value: [nil, '']).count,
      last_updated: SystemSetting.maximum(:updated_at)&.strftime('%d.%m.%Y %H:%M') || 'Никогда',
      ready_for_production: SystemSetting.count > 0,
      details: settings.map do |category, category_settings|
        {
          category: category,
          settings_count: category_settings.count,
          configured_count: category_settings.count { |s| s.value.present? },
          settings: category_settings.map do |setting|
            {
              key: setting.key,
              configured: setting.value.present?,
              type: setting.setting_type,
              description: setting.description,
              is_sensitive: setting.sensitive?
            }
          end
        }
      end
    }
  end

  # Диагностика email настроек
  def diagnose_email_settings
    email_settings = EmailSetting.current
    
    {
      status: email_settings.enabled? ? 'enabled' : 'disabled',
      configured: email_settings.smtp_host.present? && email_settings.from_email.present?,
      ready_for_production: email_settings.ready_for_production?,
      valid_configuration: email_settings.valid_configuration?,
      test_mode: email_settings.test_mode?,
      smtp_host: email_settings.smtp_host.present? ? 'настроен' : 'не настроен',
      smtp_port: email_settings.smtp_port || 'не настроен',
      from_email: email_settings.from_email.present? ? 'настроен' : 'не настроен',
      authentication: email_settings.smtp_authentication.present? ? 'настроена' : 'не настроена',
      last_updated: email_settings.updated_at&.strftime('%d.%m.%Y %H:%M') || 'Никогда',
      issues: get_email_issues(email_settings)
    }
  end

  # Диагностика push настроек
  def diagnose_push_settings
    push_settings = PushSetting.current
    
    {
      status: push_settings.enabled? ? 'enabled' : 'disabled',
      configured: push_settings.vapid_public_key.present? && push_settings.vapid_private_key.present?,
      ready_for_production: push_settings.ready_for_production?,
      valid_configuration: push_settings.valid_configuration?,
      test_mode: push_settings.test_mode?,
      vapid_keys: push_settings.vapid_public_key.present? ? 'настроены' : 'не настроены',
      firebase_config: push_settings.effective_firebase_api_key.present? ? 'настроен' : 'не настроен',
      daily_limit: push_settings.daily_limit,
      rate_limit: push_settings.rate_limit,
      last_updated: push_settings.updated_at&.strftime('%d.%m.%Y %H:%M') || 'Никогда',
      system_status: push_settings.system_status,
      issues: get_push_issues(push_settings)
    }
  end

  # Диагностика telegram настроек
  def diagnose_telegram_settings
    telegram_settings = TelegramSetting.current
    
    {
      status: telegram_settings.enabled? ? 'enabled' : 'disabled',
      configured: telegram_settings.bot_token.present?,
      ready_for_production: telegram_settings.ready_for_production?,
      valid_configuration: telegram_settings.valid_configuration?,
      test_mode: telegram_settings.test_mode?,
      bot_token: telegram_settings.bot_token.present? ? 'настроен' : 'не настроен',
      bot_username: telegram_settings.bot_username.present? ? telegram_settings.bot_username : 'не получен',
      webhook_url: telegram_settings.webhook_url.present? ? 'настроен' : 'не настроен',
      admin_chat_id: telegram_settings.admin_chat_id.present? ? 'настроен' : 'не настроен',
      subscriptions_count: TelegramSubscription.count,
      last_updated: telegram_settings.updated_at&.strftime('%d.%m.%Y %H:%M') || 'Никогда',
      system_status: telegram_settings.system_status,
      issues: get_telegram_issues(telegram_settings)
    }
  end

  # Диагностика Google OAuth настроек
  def diagnose_google_oauth_settings
    oauth_settings = GoogleOauthSetting.current
    
    {
      status: oauth_settings.enabled? ? 'enabled' : 'disabled',
      configured: oauth_settings.client_id.present? && oauth_settings.client_secret.present?,
      ready_for_production: oauth_settings.ready_for_production?,
      valid_configuration: oauth_settings.valid_configuration?,
      client_id: oauth_settings.client_id.present? ? 'настроен' : 'не настроен',
      client_secret: oauth_settings.client_secret.present? ? 'настроен' : 'не настроен',
      redirect_uri: oauth_settings.redirect_uri.present? ? 'настроен' : 'не настроен',
      last_updated: oauth_settings.updated_at&.strftime('%d.%m.%Y %H:%M') || 'Никогда',
      system_status: oauth_settings.system_status,
      issues: get_oauth_issues(oauth_settings)
    }
  end

  # Диагностика каналов уведомлений
  def diagnose_notification_channels
    channels = NotificationChannelSetting.all
    enabled_channels = channels.select(&:enabled?)
    
    {
      total_channels: channels.count,
      enabled_channels: enabled_channels.count,
      disabled_channels: channels.count - enabled_channels.count,
      channels_by_priority: enabled_channels.sort_by(&:priority).map do |channel|
        {
          type: channel.channel_type,
          name: channel.channel_name,
          priority: channel.priority,
          enabled: channel.enabled?,
          daily_limit: channel.daily_limit,
          rate_limit_per_minute: channel.rate_limit_per_minute,
          retry_attempts: channel.retry_attempts
        }
      end,
      last_updated: channels.maximum(:updated_at)&.strftime('%d.%m.%Y %H:%M') || 'Никогда'
    }
  end

  # Расчет общего статуса системы
  def calculate_overall_status
    issues = []
    warnings = []
    
    # Проверяем email
    email_settings = EmailSetting.current
    unless email_settings.ready_for_production?
      issues << 'Email уведомления не готовы к продакшену'
    end
    
    # Проверяем push
    push_settings = PushSetting.current
    unless push_settings.ready_for_production?
      warnings << 'Push уведомления не настроены'
    end
    
    # Проверяем telegram
    telegram_settings = TelegramSetting.current
    unless telegram_settings.ready_for_production?
      warnings << 'Telegram интеграция не настроена'
    end
    
    # Проверяем Google OAuth
    oauth_settings = GoogleOauthSetting.current
    unless oauth_settings.ready_for_production?
      warnings << 'Google OAuth не настроен'
    end
    
    # Проверяем каналы уведомлений
    enabled_channels = NotificationChannelSetting.enabled.count
    if enabled_channels == 0
      issues << 'Не настроен ни один канал уведомлений'
    end
    
    # Определяем общий статус
    overall_status = if issues.any?
                       'critical'
                     elsif warnings.any?
                       'warning'
                     else
                       'healthy'
                     end
    
    {
      status: overall_status,
      issues_count: issues.count,
      warnings_count: warnings.count,
      issues: issues,
      warnings: warnings,
      score: calculate_health_score,
      recommendations: get_recommendations
    }
  end

  # Получение проблем с email настройками
  def get_email_issues(settings)
    issues = []
    issues << 'SMTP хост не настроен' unless settings.smtp_host.present?
    issues << 'Email отправителя не настроен' unless settings.from_email.present?
    issues << 'SMTP порт не настроен' unless settings.smtp_port.present?
    issues << 'Аутентификация настроена, но отсутствует логин или пароль' if settings.smtp_authentication.present? && (settings.smtp_username.blank? || settings.smtp_password.blank?)
    issues
  end

  # Получение проблем с push настройками
  def get_push_issues(settings)
    issues = []
    issues << 'VAPID ключи не настроены' unless settings.vapid_public_key.present? && settings.vapid_private_key.present?
    issues << 'Firebase конфигурация не настроена' unless settings.effective_firebase_api_key.present?
    issues << 'Неверный формат VAPID публичного ключа' if settings.vapid_public_key.present? && !settings.vapid_public_key.match?(/\A[A-Za-z0-9_-]{87}=\z/)
    issues << 'Неверный формат VAPID приватного ключа' if settings.vapid_private_key.present? && !settings.vapid_private_key.match?(/\A[A-Za-z0-9_-]{42}=\z/)
    issues
  end

  # Получение проблем с telegram настройками
  def get_telegram_issues(settings)
    issues = []
    issues << 'Токен бота не настроен' unless settings.bot_token.present?
    issues << 'Chat ID администратора не настроен' unless settings.admin_chat_id.present?
    issues << 'Webhook URL не настроен' unless settings.webhook_url.present?
    issues << 'Имя пользователя бота не получено' unless settings.bot_username.present?
    issues
  end

  # Получение проблем с OAuth настройками
  def get_oauth_issues(settings)
    issues = []
    issues << 'Client ID не настроен' unless settings.client_id.present?
    issues << 'Client Secret не настроен' unless settings.client_secret.present?
    issues << 'Redirect URI не настроен' unless settings.redirect_uri.present?
    issues
  end

  # Расчет показателя здоровья системы (0-100)
  def calculate_health_score
    total_components = 5 # email, push, telegram, oauth, channels
    healthy_components = 0
    
    healthy_components += 1 if EmailSetting.current.ready_for_production?
    healthy_components += 1 if PushSetting.current.ready_for_production?
    healthy_components += 1 if TelegramSetting.current.ready_for_production?
    healthy_components += 1 if GoogleOauthSetting.current.ready_for_production?
    healthy_components += 1 if NotificationChannelSetting.enabled.any?
    
    (healthy_components.to_f / total_components * 100).round
  end

  # Получение рекомендаций по улучшению
  def get_recommendations
    recommendations = []
    
    unless EmailSetting.current.ready_for_production?
      recommendations << {
        priority: 'high',
        component: 'email',
        message: 'Настройте Email уведомления для базовой функциональности системы',
        action_url: '/admin/settings/email'
      }
    end
    
    unless NotificationChannelSetting.enabled.any?
      recommendations << {
        priority: 'high',
        component: 'notifications',
        message: 'Настройте хотя бы один канал уведомлений',
        action_url: '/admin/settings/notification-channels'
      }
    end
    
    unless PushSetting.current.ready_for_production?
      recommendations << {
        priority: 'medium',
        component: 'push',
        message: 'Настройте Push уведомления для улучшения пользовательского опыта',
        action_url: '/admin/settings/push'
      }
    end
    
    unless TelegramSetting.current.ready_for_production?
      recommendations << {
        priority: 'medium',
        component: 'telegram',
        message: 'Настройте Telegram интеграцию для дополнительного канала уведомлений',
        action_url: '/admin/settings/telegram'
      }
    end
    
    unless GoogleOauthSetting.current.ready_for_production?
      recommendations << {
        priority: 'low',
        component: 'oauth',
        message: 'Настройте Google OAuth для упрощения регистрации пользователей',
        action_url: '/admin/settings/google-oauth'
      }
    end
    
    recommendations
  end

  # Проверка прав администратора
  def ensure_admin
    render json: { error: 'Доступ запрещен' }, status: :forbidden unless current_user&.admin?
  end
end