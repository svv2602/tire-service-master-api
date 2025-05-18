module Api
  module V1
    class NotificationsController < ApiController
      before_action :set_notification, only: [:show, :update]
      
      # GET /api/v1/notifications
      def index
        @notifications = current_user.notifications.order(created_at: :desc)
        
        # Фильтрация по прочитанным/непрочитанным
        if params[:read] == 'true'
          @notifications = @notifications.where(is_read: true)
        elsif params[:read] == 'false'
          @notifications = @notifications.where(is_read: false)
        end
        
        # Фильтрация по типу уведомления
        @notifications = @notifications.where(notification_type: params[:type]) if params[:type].present?
        
        render json: paginate(@notifications)
      end
      
      # GET /api/v1/notifications/:id
      def show
        render json: @notification
      end
      
      # PATCH/PUT /api/v1/notifications/:id
      def update
        if @notification.update(notification_params)
          render json: @notification
        else
          render json: { errors: @notification.errors }, status: :unprocessable_entity
        end
      end
      
      private
      
      def set_notification
        @notification = current_user.notifications.find(params[:id])
      end
      
      def notification_params
        # Позволяем обновить только статус прочтения
        params.require(:notification).permit(:is_read)
      end
    end
  end
end
