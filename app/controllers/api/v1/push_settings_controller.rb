class Api::V1::PushSettingsController < ApplicationController
  before_action :authenticate_request
  before_action :set_push_settings, only: [:show, :update, :test_notification]

  # GET /api/v1/push_settings
  def show
    authorize_admin!
    
    render json: {
      push_settings: format_settings(@push_settings),
      statistics: get_push_statistics,
      vapid_public_key: ENV['VAPID_PUBLIC_KEY'],
      service_worker_status: check_service_worker_status
    }
  end

  # PATCH/PUT /api/v1/push_settings
  def update
    authorize_admin!
    
    begin
      # Обновляем настройки через кэш (как в SettingsController)
      push_settings_params.each do |key, value|
        # Преобразуем ключи для сохранения в кэше
        cache_key = case key.to_s
        when 'enabled' then 'push_enabled'
        when 'service_worker_enabled' then 'service_worker_enabled'
        when 'test_mode' then 'push_test_mode'
        when 'daily_limit' then 'push_daily_limit'
        when 'rate_limit_per_minute' then 'push_rate_limit_per_minute'
        else "push_#{key}"
        end
        
        update_setting(cache_key, value)
      end
      
      # Обновляем локальный объект для ответа
      @push_settings = set_push_settings
      
      render json: {
        message: 'Настройки Push уведомлений успешно обновлены',
        push_settings: format_settings(@push_settings)
      }
    rescue => e
      render json: {
        errors: [e.message]
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/push_settings/test_notification
  def test_notification
    authorize_admin!
    
    unless ENV['VAPID_PUBLIC_KEY'].present? && ENV['VAPID_PRIVATE_KEY'].present?
      render json: {
        success: false,
        message: 'VAPID ключи не настроены в переменных окружения'
      }, status: :unprocessable_entity
      return
    end

    # Отправляем тестовое уведомление текущему пользователю
    if current_user.push_subscriptions.active.any?
      push_service = PushService.new
      success = push_service.send_notification(
        current_user,
        'Тестове повідомлення',
        'Система push-сповіщень працює коректно!',
        {
          icon: '/favicon.ico',
          badge: '/favicon.ico',
          url: '/admin/notifications/push-settings'
        }
      )
      
      if success
        render json: {
          success: true,
          message: 'Тестовое уведомление отправлено успешно!'
        }
      else
        render json: {
          success: false,
          message: 'Не удалось отправить уведомление. Проверьте подписки.'
        }, status: :unprocessable_entity
      end
    else
      render json: {
        success: false,
        message: 'У вас нет активных Push подписок. Разрешите уведомления в браузере.'
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/push_settings/subscriptions
  def subscriptions
    authorize_admin!
    
    subscriptions = PushSubscription.includes(:user)
                                   .active
                                   .recent
                                   .limit(100)
    
    render json: {
      subscriptions: subscriptions.map { |sub| format_subscription(sub) },
      total_count: PushSubscription.count,
      active_count: PushSubscription.active.count
    }
  end

  private

  def set_push_settings
    # Используем систему настроек через Rails.cache как в SettingsController
    @push_settings = OpenStruct.new({
      enabled: get_setting('push_enabled', false),
      firebase_api_key: get_setting('firebase_api_key', ''),
      firebase_project_id: get_setting('firebase_project_id', ''),
      firebase_app_id: get_setting('firebase_app_id', ''),
      vapid_public_key: ENV['VAPID_PUBLIC_KEY'] || '',
      service_worker_enabled: get_setting('service_worker_enabled', true),
      test_mode: get_setting('push_test_mode', false),
      daily_limit: get_setting('push_daily_limit', 1000),
      rate_limit_per_minute: get_setting('push_rate_limit_per_minute', 60)
    })
  end

  def push_settings_params
    params.require(:push_settings).permit(
      :enabled, :firebase_api_key, :firebase_project_id, :firebase_app_id,
      :service_worker_enabled, :test_mode, :daily_limit, :rate_limit_per_minute
    )
  end

  def format_settings(settings)
    {
      enabled: settings.enabled,
      firebase_api_key: settings.firebase_api_key.present? ? "#{settings.firebase_api_key[0..10]}..." : '',
      firebase_project_id: settings.firebase_project_id,
      firebase_app_id: settings.firebase_app_id.present? ? "#{settings.firebase_app_id[0..10]}..." : '',
      vapid_configured: ENV['VAPID_PUBLIC_KEY'].present? && ENV['VAPID_PRIVATE_KEY'].present?,
      vapid_public_key: ENV['VAPID_PUBLIC_KEY'] || '',
      service_worker_enabled: settings.service_worker_enabled,
      test_mode: settings.test_mode,
      daily_limit: settings.daily_limit,
      rate_limit_per_minute: settings.rate_limit_per_minute,
      system_status: get_push_system_status,
      status_color: get_push_status_color,
      ready_for_production: push_ready_for_production?
    }
  end

  def format_subscription(subscription)
    {
      id: subscription.id,
      user_id: subscription.user_id,
      user_name: "#{subscription.user.first_name} #{subscription.user.last_name}",
      user_email: subscription.user.email,
      endpoint: subscription.display_endpoint,
      browser: subscription.browser_info,
      is_active: subscription.is_active,
      status: subscription.status_text,
      notifications_sent: subscription.notifications_sent,
      notifications_failed: subscription.notifications_failed,
      success_rate: subscription.success_rate,
      last_used_at: subscription.last_used_at,
      created_at: subscription.created_at
    }
  end

  def get_push_statistics
    {
      total_subscriptions: PushSubscription.count,
      active_subscriptions: PushSubscription.active.count,
      inactive_subscriptions: PushSubscription.inactive.count,
      stale_subscriptions: PushSubscription.active.select(&:stale?).count,
      total_sent: PushSubscription.sum(:notifications_sent),
      total_failed: PushSubscription.sum(:notifications_failed),
      success_rate: calculate_overall_success_rate,
      browsers: get_browser_statistics
    }
  end

  def get_browser_statistics
    PushSubscription.active.group_by(&:browser_info).transform_values(&:count)
  end

  def calculate_overall_success_rate
    total_sent = PushSubscription.sum(:notifications_sent)
    total_failed = PushSubscription.sum(:notifications_failed)
    
    return 0 if total_sent == 0
    ((total_sent.to_f / (total_sent + total_failed)) * 100).round(2)
  end

  def get_push_system_status
    return 'Не настроен' unless ENV['VAPID_PUBLIC_KEY'].present?
    return 'Отключен' unless get_setting('push_enabled', false)
    return 'Тестовый режим' if get_setting('push_test_mode', false)
    'Активен'
  end

  def get_push_status_color
    case get_push_system_status
    when 'Активен' then 'success'
    when 'Тестовый режим' then 'warning'
    when 'Отключен' then 'default'
    else 'error'
    end
  end

  def push_ready_for_production?
    ENV['VAPID_PUBLIC_KEY'].present? && 
    ENV['VAPID_PRIVATE_KEY'].present? && 
    get_setting('push_enabled', false)
  end

  def check_service_worker_status
    {
      vapid_configured: ENV['VAPID_PUBLIC_KEY'].present?,
      service_worker_file_exists: File.exist?(Rails.root.join('public', 'sw.js')),
      manifest_configured: File.exist?(Rails.root.join('public', 'manifest.json'))
    }
  end

  def authorize_admin!
    unless current_user&.admin?
      render json: { error: 'Доступ запрещен' }, status: :forbidden
    end
  end

  def get_setting(key, default_value)
    cached_value = Rails.cache.read("settings_#{key}")
    return cached_value unless cached_value.nil?
    
    Rails.cache.write("settings_#{key}", default_value, expires_in: 1.year)
    default_value
  end

  def update_setting(key, value)
    Rails.cache.write("settings_#{key}", value, expires_in: 1.year)
  end
end
