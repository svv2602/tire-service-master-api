class Api::V1::PushSubscriptionsController < ApplicationController
  skip_after_action :verify_authorized
  before_action :authenticate_request
  before_action :set_push_subscription, only: [:show, :destroy]

  # GET /api/v1/push_subscriptions
  def index
    subscriptions = current_user.push_subscriptions.active.recent
    
    render json: {
      subscriptions: subscriptions.map { |sub| format_subscription(sub) },
      total_count: current_user.push_subscriptions.count,
      active_count: current_user.push_subscriptions.active.count
    }
  end

  # GET /api/v1/push_subscriptions/:id
  def show
    render json: format_subscription(@push_subscription)
  end

  # POST /api/v1/push_subscriptions
  def create
    subscription_data = params[:subscription]
    
    unless subscription_data
      render json: { errors: ['Данные подписки обязательны'] }, status: :unprocessable_entity
      return
    end

    # Проверяем, не существует ли уже подписка с таким endpoint
    existing_subscription = PushSubscription.find_by(endpoint: subscription_data[:endpoint])
    
    if existing_subscription
      if existing_subscription.user_id == current_user.id
        # Обновляем существующую подписку
        if existing_subscription.update(subscription_params)
          existing_subscription.activate!
          render json: {
            message: 'Подписка обновлена',
            subscription: format_subscription(existing_subscription)
          }
        else
          render json: { errors: existing_subscription.errors.full_messages }, status: :unprocessable_entity
        end
      else
        # Подписка принадлежит другому пользователю - создаем новую
        create_new_subscription
      end
    else
      # Создаем новую подписку
      create_new_subscription
    end
  end

  # DELETE /api/v1/push_subscriptions/:id
  def destroy
    @push_subscription.destroy
    render json: { message: 'Подписка удалена' }
  end

  # DELETE /api/v1/push_subscriptions (by endpoint)
  def destroy_by_endpoint
    endpoint = params[:endpoint]
    
    unless endpoint
      render json: { errors: ['Endpoint обязателен'] }, status: :unprocessable_entity
      return
    end

    subscription = current_user.push_subscriptions.find_by(endpoint: endpoint)
    
    if subscription
      subscription.destroy
      render json: { message: 'Подписка удалена' }
    else
      render json: { message: 'Подписка не найдена' }, status: :not_found
    end
  end

  # POST /api/v1/push_subscriptions/:id/activate
  def activate
    @push_subscription.activate!
    render json: {
      message: 'Подписка активирована',
      subscription: format_subscription(@push_subscription)
    }
  end

  # POST /api/v1/push_subscriptions/:id/deactivate
  def deactivate
    @push_subscription.deactivate!
    render json: {
      message: 'Подписка деактивирована',
      subscription: format_subscription(@push_subscription)
    }
  end

  # POST /api/v1/push_subscriptions/:id/test
  def test_notification
    push_service = PushService.new
    
    success = push_service.send_notification(
      current_user,
      'Тестовое уведомление',
      'Ваша Push подписка работает корректно!',
      {
        icon: '/favicon.ico',
        badge: '/favicon.ico',
        url: '/admin/notifications/push-settings'
      }
    )
    
    if success
      render json: {
        success: true,
        message: 'Тестовое уведомление отправлено'
      }
    else
      render json: {
        success: false,
        message: 'Не удалось отправить уведомление'
      }, status: :unprocessable_entity
    end
  end

  private

  def create_new_subscription
    @push_subscription = current_user.push_subscriptions.build(subscription_params)
    
    if @push_subscription.save
      @push_subscription.activate!
      
      render json: {
        message: 'Подписка создана успешно',
        subscription: format_subscription(@push_subscription)
      }, status: :created
    else
      render json: { errors: @push_subscription.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def set_push_subscription
    @push_subscription = current_user.push_subscriptions.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Подписка не найдена' }, status: :not_found
  end

  def subscription_params
    subscription_data = params[:subscription]
    
    {
      endpoint: subscription_data[:endpoint],
      p256dh_key: subscription_data.dig(:keys, :p256dh),
      auth_key: subscription_data.dig(:keys, :auth),
      user_agent: params[:user_agent]
    }
  end

  def format_subscription(subscription)
    {
      id: subscription.id,
      endpoint: subscription.display_endpoint,
      browser: subscription.browser_info,
      is_active: subscription.is_active,
      status: subscription.status_text,
      notifications_sent: subscription.notifications_sent,
      notifications_failed: subscription.notifications_failed,
      success_rate: subscription.success_rate,
      total_notifications: subscription.total_notifications,
      last_used_at: subscription.last_used_at,
      created_at: subscription.created_at,
      can_receive: subscription.can_receive_notifications?
    }
  end
end 