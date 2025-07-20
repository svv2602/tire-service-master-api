module Api
  module V1
    class NotificationsController < ApiController
      before_action :set_notification, only: [:show, :update, :destroy]
      before_action :set_recipient, only: [:index, :create, :mark_all_as_read, :destroy_all, :stats]
      
      # GET /api/v1/notifications
      # Параметры: page, per_page, read, category, priority, search
      def index
        @notifications = @recipient.notifications.recent
        
        # Фильтрация по статусу прочтения
        case params[:read]
        when 'true'
          @notifications = @notifications.read
        when 'false'
          @notifications = @notifications.unread
        end
        
        # Фильтрация по категории
        @notifications = @notifications.by_category(params[:category]) if params[:category].present?
        
        # Фильтрация по приоритету
        @notifications = @notifications.by_priority(params[:priority]) if params[:priority].present?
        
        # Поиск по тексту
        if params[:search].present?
          search_term = "%#{params[:search]}%"
          @notifications = @notifications.where(
            "title ILIKE ? OR message ILIKE ?", 
            search_term, search_term
          )
        end
        
        # Пагинация
        page = params[:page]&.to_i || 1
        per_page = [params[:per_page]&.to_i || 20, 100].min
        
        @total_count = @notifications.count
        @notifications = @notifications.offset((page - 1) * per_page).limit(per_page)
        
        render json: {
          notifications: @notifications.map { |n| serialize_notification(n) },
          pagination: {
            current_page: page,
            per_page: per_page,
            total_count: @total_count,
            total_pages: (@total_count.to_f / per_page).ceil
          }
        }
      end
      
      # GET /api/v1/notifications/:id
      def show
        render json: serialize_notification(@notification)
      end
      
      # POST /api/v1/notifications
      def create
        @notification = @recipient.notifications.build(notification_create_params)
        
        if @notification.save
          render json: serialize_notification(@notification), status: :created
        else
          render json: { errors: @notification.errors }, status: :unprocessable_entity
        end
      end
      
      # PATCH/PUT /api/v1/notifications/:id
      def update
        if @notification.update(notification_update_params)
          render json: serialize_notification(@notification)
        else
          render json: { errors: @notification.errors }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/notifications/:id
      def destroy
        @notification.destroy
        head :no_content
      end
      
      # POST /api/v1/notifications/mark_all_as_read
      def mark_all_as_read
        count = @recipient.notifications.unread.update_all(
          is_read: true, 
          read_at: Time.current
        )
        
        render json: { 
          message: "Marked #{count} notifications as read",
          marked_count: count
        }
      end
      
      # DELETE /api/v1/notifications/destroy_all
      def destroy_all
        # Фильтры для массового удаления
        notifications = @recipient.notifications
        
        if params[:read] == 'true'
          notifications = notifications.read
        elsif params[:category].present?
          notifications = notifications.by_category(params[:category])
        end
        
        count = notifications.count
        notifications.destroy_all
        
        render json: { 
          message: "Deleted #{count} notifications",
          deleted_count: count
        }
      end
      
      # GET /api/v1/notifications/stats
      def stats
        stats = Notification.stats_for_recipient(@recipient.class.name, @recipient.id)
        
        render json: {
          stats: stats,
          recent_activity: {
            today: @recipient.notifications.created_today.count,
            this_week: @recipient.notifications.created_this_week.count
          }
        }
      end
      
      private
      
      def set_notification
        @notification = current_user.notifications.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Notification not found' }, status: :not_found
      end
      
      def set_recipient
        # Определяем получателя уведомлений на основе текущего пользователя
        if current_user.admin?
          @recipient = current_user
        elsif current_user.client
          @recipient = current_user.client
        elsif current_user.partner
          @recipient = current_user.partner
        else
          @recipient = current_user
        end
      end
      
      def notification_create_params
        params.require(:notification).permit(
          :notification_type_id, :title, :message, :send_via, 
          :priority, :category, :action_url, :expires_at
        )
      end
      
      def notification_update_params
        # Пользователи могут обновлять только статус прочтения
        params.require(:notification).permit(:is_read)
      end
      
      def serialize_notification(notification)
        {
          id: notification.id,
          type: notification.notification_type&.name,
          title: notification.title,
          message: notification.message,
          priority: notification.priority,
          category: notification.category,
          is_read: notification.is_read,
          sent_at: notification.sent_at,
          read_at: notification.read_at,
          created_at: notification.created_at,
          action_url: notification.action_url,
          expires_at: notification.expires_at
        }
      end
    end
  end
end
