module Api
  module V1
    class ReviewsController < ApiController
      skip_before_action :authenticate_request, only: [:index, :show], if: -> { params[:service_point_id].present? }
      before_action :set_review, only: [:show, :update, :destroy]
      before_action :set_client_reviews, only: [:index], if: -> { params[:client_id].present? }
      before_action :set_service_point_reviews, only: [:index], if: -> { params[:service_point_id].present? }
      
      # GET /api/v1/clients/:client_id/reviews
      # GET /api/v1/service_points/:service_point_id/reviews
      def index
        @reviews = policy_scope(@reviews || Review)
        
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
        
        # Сортировка
        if params[:sort_by] == 'rating'
          @reviews = @reviews.order(rating: params[:sort_direction] || 'desc')
        else
          @reviews = @reviews.order(created_at: :desc)
        end
        
        render json: paginate(@reviews)
      end
      
      # GET /api/v1/clients/:client_id/reviews/:id
      # GET /api/v1/service_points/:service_point_id/reviews/:id
      def show
        authorize @review
        render json: @review
      end
      
      # POST /api/v1/clients/:client_id/reviews
      def create
        @client = Client.find(params[:client_id])
        @booking = @client.bookings.find(params[:booking_id])
        
        # Проверяем, что бронирование выполнено
        unless @booking.status.name == "completed"
          return render json: { error: "Can't review unfinished booking" }, status: :unprocessable_entity
        end
        
        # Проверяем, что отзыв на это бронирование еще не оставлен
        if Review.exists?(booking_id: @booking.id)
          return render json: { error: "Review for this booking already exists" }, status: :unprocessable_entity
        end
        
        @review = Review.new(review_params)
        @review.client = @client
        @review.booking = @booking
        @review.service_point = @booking.service_point
        
        authorize @review
        
        if @review.save
          # Пересчитываем рейтинг сервисной точки
          @review.service_point.recalculate_metrics!
          
          render json: @review, status: :created
        else
          render json: { errors: @review.errors }, status: :unprocessable_entity
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
        
        if @review.update(review_params)
          # Пересчитываем рейтинг сервисной точки
          @review.service_point.recalculate_metrics!
          
          render json: @review
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
      
      def set_review
        @review = if params[:client_id].present?
                    Client.find(params[:client_id]).reviews.find(params[:id])
                  elsif params[:service_point_id].present?
                    ServicePoint.find(params[:service_point_id]).reviews.find(params[:id])
                  else
                    Review.find(params[:id])
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
        params.require(:review).permit(:rating, :comment, :reply)
      end
    end
  end
end
