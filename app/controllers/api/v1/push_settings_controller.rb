class Api::V1::PushSettingsController < ApplicationController
  skip_after_action :verify_authorized
  before_action :authenticate_request
  before_action :set_push_settings, only: [:show, :update, :test_notification]

  # GET /api/v1/push_settings
  def show
    authorize_admin!
    
    render json: {
      push_settings: format_settings(@push_settings),
      statistics: get_push_statistics,
      service_worker_status: check_service_worker_status
    }
  end

  # PATCH/PUT /api/v1/push_settings
  def update
    authorize_admin!
    
    if @push_settings.update(push_settings_params)
      render json: {
        message: 'Настройки Push уведомлений успешно обновлены',
        push_settings: format_settings(@push_settings)
      }
    else
      render json: {
        errors: @push_settings.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/push_settings/test_notification
  def test_notification
    authorize_admin!
    
    unless @push_settings.effective_vapid_public_key.present? && @push_settings.effective_vapid_private_key.present?
      render json: {
        success: false,
        message: 'VAPID ключи не настроены. Добавьте их в настройках Push уведомлений.'
      }, status: :unprocessable_entity
      return
    end

    # Проверяем наличие Push подписок у текущего пользователя
    user_subscriptions = current_user.push_subscriptions.active
    
    if user_subscriptions.any?
      # ВРЕМЕННОЕ РЕШЕНИЕ: Обходим проблему с OpenSSL 3.0
      Rails.logger.info "🧪 Симуляция отправки Push уведомления для пользователя #{current_user.email}"
      
      render json: {
        success: true,
        message: "✅ Тестовое Push уведомление симулировано успешно! (#{user_subscriptions.count} подписок)",
        info: {
          simulated: true,
          reason: 'OpenSSL 3.0 несовместим с webpush gem 1.1.0',
          user_subscriptions: user_subscriptions.count,
          subscriptions_details: user_subscriptions.map do |sub|
            {
              id: sub.id,
              browser: sub.user_agent&.split('/')&.first || 'Unknown',
              created: sub.created_at.strftime('%d.%m.%Y %H:%M')
            }
          end,
          next_steps: [
            'В продакшне обновить webpush gem или использовать Firebase FCM',
            'Пока что система готова, но Push отправка симулируется'
          ]
        }
      }
    else
      render json: {
        success: true,
        message: 'VAPID ключи настроены корректно! Для получения Push уведомлений разрешите уведомления в браузере и подпишитесь на них.',
        info: {
          vapid_configured: true,
          user_subscriptions: 0,
          total_subscriptions: PushSubscription.count,
          instructions: 'Откройте DevTools -> Application -> Service Workers для регистрации SW',
          note: 'У вас пока нет активных Push подписок, поэтому тестовое уведомление не может быть отправлено'
        }
      }
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
    @push_settings = PushSetting.current
  end

  def push_settings_params
    params.require(:push_settings).permit(
      :vapid_public_key, :vapid_private_key, :firebase_api_key, 
      :firebase_project_id, :firebase_app_id, :enabled, :test_mode, 
      :daily_limit, :rate_limit
    )
  end

  def format_settings(settings)
    {
      id: settings.id,
      vapid_public_key: settings.masked_vapid_public_key,
      vapid_private_key: settings.masked_vapid_private_key,
      firebase_api_key: settings.firebase_api_key.present? ? "#{settings.firebase_api_key[0..10]}..." : nil,
      firebase_project_id: settings.firebase_project_id,
      firebase_app_id: settings.firebase_app_id.present? ? "#{settings.firebase_app_id[0..10]}..." : nil,
      enabled: settings.enabled,
      test_mode: settings.test_mode,
      daily_limit: settings.daily_limit,
      rate_limit: settings.rate_limit,
      system_status: settings.system_status,
      status_color: settings.status_color,
      status_text: settings.status_text,
      ready_for_production: settings.ready_for_production?,
      valid_configuration: settings.valid_configuration?,
      vapid_configured: settings.effective_vapid_public_key.present? && settings.effective_vapid_private_key.present?,
      created_at: settings.created_at,
      updated_at: settings.updated_at
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

  def check_service_worker_status
    {
      vapid_configured: @push_settings.effective_vapid_public_key.present?,
      service_worker_file_exists: File.exist?(Rails.root.join('public', 'sw.js')),
      manifest_configured: File.exist?(Rails.root.join('public', 'manifest.json'))
    }
  end

  def authorize_admin!
    unless current_user&.admin?
      render json: { error: 'Доступ запрещен' }, status: :forbidden
    end
  end
end
