# API контроллер для управления постами обслуживания
class Api::V1::ServicePostsController < Api::V1::ApiController
  before_action :authenticate_request
  before_action :set_service_point
  before_action :set_service_post, only: [:show, :update, :activate, :deactivate, :statistics]
  before_action :check_partner_permission, only: [:create, :update, :activate, :deactivate]
  
  # GET /api/v1/service_points/:service_point_id/service_posts
  def index
    @service_posts = @service_point.service_posts.ordered_by_post_number
    
    render json: @service_posts, each_serializer: ServicePostSerializer
  end
  
  # GET /api/v1/service_points/:service_point_id/service_posts/:id
  def show
    render json: @service_post, serializer: ServicePostSerializer
  end
  
  # POST /api/v1/service_points/:service_point_id/service_posts
  def create
    @service_post = @service_point.service_posts.build(service_post_params)
    
    if @service_post.save
      render json: @service_post, serializer: ServicePostSerializer, status: :created
    else
      render json: { errors: @service_post.errors }, status: :unprocessable_entity
    end
  end
  
  # PUT/PATCH /api/v1/service_points/:service_point_id/service_posts/:id
  def update
    begin
      updated_post = ServicePostConfigurationService.update_post_configuration(@service_post.id, service_post_params)
      render json: updated_post, serializer: ServicePostSerializer
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
  
  # POST /api/v1/service_points/:service_point_id/service_posts/:id/activate
  def activate
    begin
      activated_post = ServicePostConfigurationService.activate_post(@service_post.id)
      render json: activated_post, serializer: ServicePostSerializer
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
  
  # POST /api/v1/service_points/:service_point_id/service_posts/:id/deactivate
  def deactivate
    begin
      deactivated_post = ServicePostConfigurationService.deactivate_post(@service_post.id)
      render json: deactivated_post, serializer: ServicePostSerializer
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
  
  # GET /api/v1/service_points/:service_point_id/service_posts/statistics
  def statistics
    date_from = params[:date_from]&.to_date || 1.month.ago.to_date
    date_to = params[:date_to]&.to_date || Date.current
    
    statistics = ServicePostConfigurationService.get_posts_statistics(
      @service_point.id, 
      date_from, 
      date_to
    )
    
    render json: { 
      statistics: statistics,
      period: {
        from: date_from,
        to: date_to
      }
    }
  end
  
  # POST /api/v1/service_points/:service_point_id/service_posts/create_defaults
  def create_defaults
    begin
      ServicePostConfigurationService.create_default_posts_for_service_point(@service_point.id)
      @service_posts = @service_point.service_posts.reload.ordered_by_post_number
      render json: @service_posts, each_serializer: ServicePostSerializer, status: :created
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_service_point
    @service_point = ServicePoint.find(params[:service_point_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Точка обслуживания не найдена' }, status: :not_found
  end
  
  def set_service_post
    @service_post = @service_point.service_posts.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Пост обслуживания не найден' }, status: :not_found
  end
  
  def check_partner_permission
    unless current_user.partner&.id == @service_point.partner_id || current_user.admin?
      render json: { error: 'Доступ запрещен' }, status: :forbidden
    end
  end
  
  def service_post_params
    params.require(:service_post).permit(:post_number, :name, :slot_duration, :description)
  end
end 