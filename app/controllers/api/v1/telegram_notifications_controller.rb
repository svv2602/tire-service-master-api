class Api::V1::TelegramNotificationsController < ApplicationController
  before_action :authenticate_request
  before_action :set_telegram_notification, only: [:show, :update, :destroy, :retry]

  # GET /api/v1/telegram_notifications
  def index
    authorize TelegramNotification, :index?
    
    @telegram_notifications = policy_scope(TelegramNotification)
                              .includes(:user, :booking)
                              .order(created_at: :desc)
                              .page(params[:page])
                              .per(params[:per_page] || 20)
    
    # Фильтрация по статусу
    @telegram_notifications = @telegram_notifications.where(status: params[:status]) if params[:status].present?
    
    # Фильтрация по типу
    @telegram_notifications = @telegram_notifications.where(notification_type: params[:type]) if params[:type].present?
    
    render json: {
      telegram_notifications: @telegram_notifications.map do |notification|
        format_notification(notification)
      end,
      pagination: {
        current_page: @telegram_notifications.current_page,
        total_pages: @telegram_notifications.total_pages,
        total_count: @telegram_notifications.total_count
      }
    }
  end

  # GET /api/v1/telegram_notifications/:id
  def show
    authorize @telegram_notification, :show?
    
    render json: {
      telegram_notification: format_notification(@telegram_notification, detailed: true)
    }
  end

  # POST /api/v1/telegram_notifications
  def create
    authorize TelegramNotification, :create?
    
    @telegram_notification = TelegramNotification.new(telegram_notification_params)
    
    if @telegram_notification.save
      # Попытка отправки уведомления
      telegram_service = TelegramService.new
      success = telegram_service.send_notification(
        @telegram_notification.user,
        @telegram_notification.message,
        { 
          type: @telegram_notification.notification_type,
          booking: @telegram_notification.booking
        }
      )
      
      render json: { 
        message: 'Уведомление создано и отправлено',
        telegram_notification: format_notification(@telegram_notification),
        sent: success
      }, status: :created
    else
      render json: { 
        errors: @telegram_notification.errors.full_messages 
      }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/telegram_notifications/:id
  def update
    authorize @telegram_notification, :update?
    
    if @telegram_notification.update(telegram_notification_params)
      render json: { 
        message: 'Уведомление успешно обновлено',
        telegram_notification: format_notification(@telegram_notification)
      }
    else
      render json: { 
        errors: @telegram_notification.errors.full_messages 
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/telegram_notifications/:id
  def destroy
    authorize @telegram_notification, :destroy?
    
    @telegram_notification.destroy
    render json: { message: 'Уведомление успешно удалено' }
  end

  # POST /api/v1/telegram_notifications/:id/retry
  def retry
    authorize @telegram_notification, :update?
    
    if @telegram_notification.can_retry?
      telegram_service = TelegramService.new
      success = telegram_service.send_notification(
        @telegram_notification.user,
        @telegram_notification.message,
        { 
          type: @telegram_notification.notification_type,
          booking: @telegram_notification.booking
        }
      )
      
      if success
        render json: { 
          message: 'Уведомление успешно отправлено повторно',
          telegram_notification: format_notification(@telegram_notification)
        }
      else
        render json: { 
          error: 'Ошибка повторной отправки уведомления' 
        }, status: :unprocessable_entity
      end
    else
      render json: { 
        error: 'Нельзя повторно отправить это уведомление' 
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/telegram_notifications/stats
  def stats
    authorize TelegramNotification, :index?
    
    stats = {
      total: TelegramNotification.count,
      sent: TelegramNotification.sent.count,
      failed: TelegramNotification.failed.count,
      pending: TelegramNotification.pending.count,
      success_rate: TelegramNotification.success_rate,
      by_type: TelegramNotification.stats_by_type
    }
    
    render json: { stats: stats }
  end

  private

  def set_telegram_notification
    @telegram_notification = TelegramNotification.find(params[:id])
  end

  def telegram_notification_params
    params.require(:telegram_notification).permit(
      :message, :chat_id, :user_id, :booking_id, :notification_type
    )
  end

  def format_notification(notification, detailed: false)
    base = {
      id: notification.id,
      message: notification.message,
      chat_id: notification.chat_id,
      notification_type: notification.notification_type,
      status: notification.status,
      sent_at: notification.sent_at,
      retry_count: notification.retry_count,
      created_at: notification.created_at,
      updated_at: notification.updated_at,
      user: {
        id: notification.user.id,
        email: notification.user.email,
        full_name: notification.user.full_name
      }
    }
    
    if notification.booking
      base[:booking] = {
        id: notification.booking.id,
        start_time: notification.booking.start_time,
        service_point_name: notification.booking.service_point&.name
      }
    end
    
    if detailed
      base.merge!({
        error_message: notification.error_message,
        telegram_response: notification.telegram_response,
        message_id: notification.message_id,
        delivery_time: notification.delivery_time,
        telegram_url: notification.telegram_url
      })
    end
    
    base
  end
end 