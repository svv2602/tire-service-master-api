module Api
  module V1
    class ReviewsController < ApiController
      skip_before_action :authenticate_request, only: [:index, :show], if: -> { params[:service_point_id].present? }
      before_action :ensure_authenticated, only: [:index], unless: -> { params[:service_point_id].present? || params[:client_id].present? }
      before_action :set_review, only: [:show, :update, :destroy]
      before_action :set_client_reviews, only: [:index], if: -> { params[:client_id].present? }
      before_action :set_service_point_reviews, only: [:index], if: -> { params[:service_point_id].present? }
      
      # GET /api/v1/clients/:client_id/reviews
      # GET /api/v1/service_points/:service_point_id/reviews
      def index
        Rails.logger.info("ReviewsController#index: Starting with current_user: #{current_user&.email}")
        Rails.logger.info("ReviewsController#index: current_user.admin?: #{current_user&.admin?}")
        Rails.logger.info("ReviewsController#index: @reviews before policy_scope: #{@reviews&.count || 'nil'}")
        
        @reviews = policy_scope(@reviews || Review)
        
        Rails.logger.info("ReviewsController#index: @reviews after policy_scope: #{@reviews.count}")
        
        # Фильтрация по статусу
        if params[:status].present?
          @reviews = @reviews.where(status: params[:status])
        end
        
        # Фильтрация по рейтингу
        if params[:rating].present?
          @reviews = @reviews.where(rating: params[:rating])
        end
        
        # Фильтрация по диапазону рейтинга
        if params[:min_rating].present?
          @reviews = @reviews.where("rating >= ?", params[:min_rating])
        end
        
        if params[:max_rating].present?
          @reviews = @reviews.where("rating <= ?", params[:max_rating])
        end
        
        # Поиск по тексту комментария, имени клиента и телефону
        if params[:search].present?
          search_term = "%#{params[:search]}%"
          @reviews = @reviews.joins(client: :user).where(
            "comment ILIKE ? OR users.first_name ILIKE ? OR users.last_name ILIKE ? OR users.phone ILIKE ?",
            search_term, search_term, search_term, search_term
          )
        end
        
        # Загружаем связанные данные для оптимизации
        @reviews = @reviews.includes({ client: :user }, :service_point, :booking)
        
        # Сортировка
        if params[:sort_by] == 'rating'
          @reviews = @reviews.order(rating: params[:sort_direction] || 'desc')
        else
          @reviews = @reviews.order(created_at: :desc)
        end
        
        Rails.logger.info("ReviewsController#index: Final @reviews count: #{@reviews.count}")
        Rails.logger.info("ReviewsController#index: Final @reviews IDs: #{@reviews.pluck(:id)}")
        
        render json: @reviews.as_json(
          include: {
            client: {
              only: [:id],
              include: {
                user: {
                  only: [:id, :email, :phone, :first_name, :last_name]
                }
              }
            },
            service_point: {
              only: [:id, :name, :address, :phone]
            },
            booking: {
              only: [:id, :booking_date, :start_time, :end_time]
            }
          },
          methods: [:status]
        )
      end
      
      # GET /api/v1/clients/:client_id/reviews/:id
      # GET /api/v1/service_points/:service_point_id/reviews/:id
      def show
        authorize @review
        render json: @review.as_json(
          include: {
            client: {
              only: [:id],
              include: {
                user: {
                  only: [:id, :email, :phone, :first_name, :last_name]
                }
              }
            },
            service_point: {
              only: [:id, :name, :address, :phone]
            },
            booking: {
              only: [:id, :booking_date, :start_time, :end_time]
            }
          },
          methods: [:status]
        )
      end
      
      # POST /api/v1/clients/:client_id/reviews (старый путь)
      # POST /api/v1/reviews (новый путь для админа)
      def create
        if params[:client_id].present?
          # Старое поведение для клиента
          @client = Client.find(params[:client_id])
          @booking = @client.bookings.find(review_params[:booking_id])
          
          # Проверяем, что бронирование выполнено
          unless @booking.status.name == "completed"
            return render json: { error: "Can't review unfinished booking" }, status: :unprocessable_entity
          end
          
          # Проверяем, что отзыв на это бронирование еще не оставлен
          if Review.exists?(booking_id: @booking.id)
            return render json: { error: "Review for this booking already exists" }, status: :unprocessable_entity
          end
          
          @review = Review.new(review_params.except(:booking_id))
          @review.client = @client
          @review.booking = @booking
          @review.service_point = @booking.service_point
          
          authorize @review
          
          if @review.save
            # Пересчитываем рейтинг сервисной точки
            @review.service_point.recalculate_metrics!
            
            render json: @review.as_json(
              include: {
                client: { only: [:id], include: { user: { only: [:id, :email, :phone, :first_name, :last_name] } } },
                service_point: { only: [:id, :name, :address, :phone] },
                booking: { only: [:id, :booking_date, :start_time, :end_time] }
              },
              methods: [:status]
            ), status: :created
          else
            render json: { errors: @review.errors }, status: :unprocessable_entity
          end
        else
          # Новый путь для администратора: POST /api/v1/reviews
          unless current_user&.admin?
            return render json: { error: 'Only admin can create review without booking' }, status: :forbidden
          end
          client = Client.find_by(id: params[:review][:client_id])
          service_point = ServicePoint.find_by(id: params[:review][:service_point_id])
          unless client && service_point
            return render json: { error: 'client_id and service_point_id are required' }, status: :unprocessable_entity
          end
          # Обработка статуса при создании
          status = params[:review][:status] || 'published'
          
          @review = Review.new(
            rating: params[:review][:rating],
            comment: params[:review][:comment],
            client: client,
            service_point: service_point,
            status: status
          )
          authorize @review
          if @review.save
            service_point.recalculate_metrics!
            render json: @review.as_json(
              include: {
                client: { only: [:id], include: { user: { only: [:id, :email, :phone, :first_name, :last_name] } } },
                service_point: { only: [:id, :name, :address, :phone] },
                booking: { only: [:id, :booking_date, :start_time, :end_time] }
              },
              methods: [:status]
            ), status: :created
          else
            render json: { errors: @review.errors }, status: :unprocessable_entity
          end
        end
      end
      
      # PATCH/PUT /api/v1/clients/:client_id/reviews/:id
      def update
        authorize @review
        
        # Клиент может обновить свой отзыв только в течение определенного времени
        unless current_user.admin?
          if Time.current - @review.created_at > 48.hours
            return render json: { error: "Cannot update review after 48 hours" }, status: :unprocessable_entity
          end
        end
        
        # Теперь используем поле status напрямую
        if @review.update(review_params)
          # Пересчитываем рейтинг сервисной точки
          @review.service_point.recalculate_metrics!
          
          render json: @review.as_json(
            include: {
              client: { only: [:id], include: { user: { only: [:id, :email, :phone, :first_name, :last_name] } } },
              service_point: { only: [:id, :name, :address, :phone] },
              booking: { only: [:id, :booking_date, :start_time, :end_time] }
            },
            methods: [:status]
          )
        else
          render json: { errors: @review.errors }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/clients/:client_id/reviews/:id
      def destroy
        authorize @review
        
        if @review.destroy
          # Пересчитываем рейтинг сервисной точки
          @review.service_point.recalculate_metrics!
          
          render json: { message: "Review was successfully deleted" }
        else
          render json: { errors: @review.errors }, status: :unprocessable_entity
        end
      end
      
      private
      
      def ensure_authenticated
        Rails.logger.info("ReviewsController#ensure_authenticated: Checking authentication")
        authenticate_request unless current_user
        Rails.logger.info("ReviewsController#ensure_authenticated: current_user after auth: #{current_user&.email}")
      end
      
      def set_review
        @review = if params[:client_id].present?
                    Client.find(params[:client_id]).reviews.includes({ client: :user }, :service_point, :booking).find(params[:id])
                  elsif params[:service_point_id].present?
                    ServicePoint.find(params[:service_point_id]).reviews.includes({ client: :user }, :service_point, :booking).find(params[:id])
                  else
                    # Прямой доступ к отзыву для админов
                    Review.includes({ client: :user }, :service_point, :booking).find(params[:id])
                  end
      end
      
      def set_client_reviews
        @client = Client.find(params[:client_id])
        @reviews = @client.reviews
      end
      
      def set_service_point_reviews
        @service_point = ServicePoint.find(params[:service_point_id])
        @reviews = @service_point.reviews
      end
      
      def review_params
        params.require(:review).permit(:booking_id, :rating, :comment, :reply, :recommend, :client_id, :service_point_id, :status)
      end
    end
  end
end
