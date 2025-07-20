class Api::V1::TelegramSubscriptionsController < ApplicationController
  before_action :authenticate_request
  before_action :set_telegram_subscription, only: [:show, :update, :destroy]

  # GET /api/v1/telegram_subscriptions
  def index
    authorize TelegramSubscription, :index?
    
    @telegram_subscriptions = policy_scope(TelegramSubscription).includes(:user)
    
    render json: {
      telegram_subscriptions: @telegram_subscriptions.map do |subscription|
        {
          id: subscription.id,
          chat_id: subscription.chat_id,
          is_active: subscription.is_active,
          status: subscription.status,
          username: subscription.username,
          full_name: subscription.full_name,
          language_code: subscription.language_code,
          last_interaction_at: subscription.last_interaction_at,
          notifications_count: subscription.notifications_count,
          success_rate: subscription.success_rate,
          created_at: subscription.created_at,
          updated_at: subscription.updated_at,
          user: {
            id: subscription.user.id,
            email: subscription.user.email,
            full_name: subscription.user.full_name
          }
        }
      end
    }
  end

  # GET /api/v1/telegram_subscriptions/:id
  def show
    authorize @telegram_subscription, :show?
    
    render json: {
      telegram_subscription: {
        id: @telegram_subscription.id,
        chat_id: @telegram_subscription.chat_id,
        is_active: @telegram_subscription.is_active,
        status: @telegram_subscription.status,
        username: @telegram_subscription.username,
        full_name: @telegram_subscription.full_name,
        language_code: @telegram_subscription.language_code,
        notification_preferences: @telegram_subscription.notification_preferences,
        last_interaction_at: @telegram_subscription.last_interaction_at,
        notifications_count: @telegram_subscription.notifications_count,
        sent_notifications_count: @telegram_subscription.sent_notifications_count,
        failed_notifications_count: @telegram_subscription.failed_notifications_count,
        success_rate: @telegram_subscription.success_rate,
        created_at: @telegram_subscription.created_at,
        updated_at: @telegram_subscription.updated_at,
        user: {
          id: @telegram_subscription.user.id,
          email: @telegram_subscription.user.email,
          full_name: @telegram_subscription.user.full_name,
          phone: @telegram_subscription.user.phone
        }
      }
    }
  end

  # PATCH/PUT /api/v1/telegram_subscriptions/:id
  def update
    authorize @telegram_subscription, :update?
    
    if @telegram_subscription.update(telegram_subscription_params)
      render json: { 
        message: 'Подписка успешно обновлена',
        telegram_subscription: format_subscription(@telegram_subscription)
      }
    else
      render json: { 
        errors: @telegram_subscription.errors.full_messages 
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/telegram_subscriptions/:id
  def destroy
    authorize @telegram_subscription, :destroy?
    
    @telegram_subscription.destroy
    render json: { message: 'Подписка успешно удалена' }
  end

  # POST /api/v1/telegram_subscriptions/:id/toggle_status
  def toggle_status
    @telegram_subscription = TelegramSubscription.find(params[:id])
    authorize @telegram_subscription, :update?
    
    if @telegram_subscription.is_active?
      @telegram_subscription.deactivate!
      message = 'Подписка деактивирована'
    else
      @telegram_subscription.activate!
      message = 'Подписка активирована'
    end
    
    render json: { 
      message: message,
      telegram_subscription: format_subscription(@telegram_subscription)
    }
  end

  # POST /api/v1/telegram_subscriptions/test_notification
  def test_notification
    subscription = TelegramSubscription.find(params[:id])
    authorize subscription, :update?
    
    telegram_service = TelegramService.new
    success = telegram_service.send_notification(
      subscription.user,
      "🧪 Тестовое уведомление от Tire Service",
      { type: 'system' }
    )
    
    if success
      render json: { message: 'Тестовое уведомление отправлено' }
    else
      render json: { error: 'Ошибка отправки уведомления' }, status: :unprocessable_entity
    end
  end

  private

  def set_telegram_subscription
    @telegram_subscription = TelegramSubscription.find(params[:id])
  end

  def telegram_subscription_params
    params.require(:telegram_subscription).permit(
      :is_active, :status, :language_code, :notification_preferences
    )
  end

  def format_subscription(subscription)
    {
      id: subscription.id,
      chat_id: subscription.chat_id,
      is_active: subscription.is_active,
      status: subscription.status,
      username: subscription.username,
      full_name: subscription.full_name,
      language_code: subscription.language_code,
      last_interaction_at: subscription.last_interaction_at,
      notifications_count: subscription.notifications_count,
      success_rate: subscription.success_rate,
      created_at: subscription.created_at,
      updated_at: subscription.updated_at
    }
  end
end 