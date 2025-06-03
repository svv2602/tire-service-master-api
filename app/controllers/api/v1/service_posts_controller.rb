# API контроллер для управления постами обслуживания
module Api
  module V1
    class ServicePostsController < ApiController
      skip_before_action :authenticate_request, only: [:index, :show]
      before_action :set_service_point
      before_action :set_service_post, only: [:show, :update, :destroy, :activate, :deactivate]
      before_action :authorize_admin_or_partner, except: [:index, :show]
      
      # GET /api/v1/service_points/:service_point_id/service_posts
      def index
        @service_posts = @service_point.service_posts.order(:post_number)
        render json: @service_posts.as_json(
          only: [:id, :post_number, :name, :slot_duration, :description, :is_active, :created_at, :updated_at]
        )
      end
      
      # GET /api/v1/service_points/:service_point_id/service_posts/:id
      def show
        render json: @service_post.as_json(
          only: [:id, :post_number, :name, :slot_duration, :description, :is_active, :created_at, :updated_at]
        )
      end
      
      # POST /api/v1/service_points/:service_point_id/service_posts
      def create
        @service_post = @service_point.service_posts.new(service_post_params)
        
        if @service_post.save
          render json: @service_post.as_json(
            only: [:id, :post_number, :name, :slot_duration, :description, :is_active, :created_at, :updated_at]
          ), status: :created
        else
          render json: { errors: @service_post.errors }, status: :unprocessable_entity
        end
      end
      
      # PATCH/PUT /api/v1/service_points/:service_point_id/service_posts/:id
      def update
        if @service_post.update(service_post_params)
          render json: @service_post.as_json(
            only: [:id, :post_number, :name, :slot_duration, :description, :is_active, :created_at, :updated_at]
          )
        else
          render json: { errors: @service_post.errors }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/service_points/:service_point_id/service_posts/:id
      def destroy
        if @service_post.destroy
          head :no_content
        else
          render json: { errors: @service_post.errors }, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/service_points/:service_point_id/service_posts/:id/activate
      def activate
        if @service_post.update(is_active: true)
          render json: { message: 'Пост активирован' }
        else
          render json: { errors: @service_post.errors }, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/service_points/:service_point_id/service_posts/:id/deactivate
      def deactivate
        if @service_post.update(is_active: false)
          render json: { message: 'Пост деактивирован' }
        else
          render json: { errors: @service_post.errors }, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/service_points/:service_point_id/service_posts/create_defaults
      def create_defaults
        post_count = params[:post_count] || @service_point.post_count || 3
        slot_duration = params[:slot_duration] || @service_point.default_slot_duration || 60
        
        created_posts = []
        errors = []
        
        (1..post_count.to_i).each do |post_number|
          # Проверяем, не существует ли уже пост с таким номером
          existing_post = @service_point.service_posts.find_by(post_number: post_number)
          
          if existing_post
            errors << "Пост #{post_number} уже существует"
            next
          end
          
          service_post = @service_point.service_posts.new(
            post_number: post_number,
            name: "Пост #{post_number}",
            slot_duration: slot_duration,
            description: "Пост обслуживания №#{post_number}",
            is_active: true
          )
          
          if service_post.save
            created_posts << service_post
          else
            errors << "Ошибка создания поста #{post_number}: #{service_post.errors.full_messages.join(', ')}"
          end
        end
        
        if errors.empty?
          render json: {
            message: "Создано #{created_posts.count} постов",
            posts: created_posts.as_json(
              only: [:id, :post_number, :name, :slot_duration, :description, :is_active]
            )
          }, status: :created
        else
          render json: {
            message: "Частичное создание постов",
            created_count: created_posts.count,
            errors: errors,
            posts: created_posts.as_json(
              only: [:id, :post_number, :name, :slot_duration, :description, :is_active]
            )
          }, status: :unprocessable_entity
        end
      end
      
      # GET /api/v1/service_points/:service_point_id/service_posts/statistics
      def statistics
        stats = {
          total_posts: @service_point.service_posts.count,
          active_posts: @service_point.service_posts.active.count,
          inactive_posts: @service_point.service_posts.where(is_active: false).count,
          average_slot_duration: @service_point.service_posts.average(:slot_duration).to_f.round(2),
          posts_by_duration: @service_point.service_posts.group(:slot_duration).count
        }
        
        render json: stats
      end
      
      private
      
      def set_service_point
        @service_point = ServicePoint.find(params[:service_point_id])
      end
      
      def set_service_post
        @service_post = @service_point.service_posts.find(params[:id])
      end
      
      def service_post_params
        params.require(:service_post).permit(:post_number, :name, :slot_duration, :description, :is_active)
      end
      
      def authorize_admin_or_partner
        unless current_user && (current_user.role.name == 'admin' || 
                (current_user.role.name == 'operator' && @service_point.partner.user_id == current_user.id))
          render json: { error: 'Unauthorized' }, status: :unauthorized
        end
      end
    end
  end
end 