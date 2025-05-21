module Api
  module V1
    class ServicesController < ApiController
      skip_before_action :authenticate_request, only: [:index, :show]
      before_action :set_service, only: [:show, :update, :destroy]
      before_action :authorize_admin!, only: [:create, :update, :destroy]
      
      # GET /api/v1/services
      def index
        @services = Service.includes(:category).active
        
        # Фильтрация по категории
        if params[:category_id].present?
          @services = @services.by_category(params[:category_id])
        end
        
        # Фильтрация по поиску
        if params[:query].present?
          query = "%#{params[:query]}%"
          @services = @services.where('name ILIKE ? OR description ILIKE ?', query, query)
        end
        
        # Сортировка
        @services = @services.sorted
        
        render json: paginate(@services)
      end
      
      # GET /api/v1/services/:id
      def show
        render json: @service.as_json(include: :category)
      end
      
      # POST /api/v1/services
      def create
        @service = Service.new(service_params)
        
        if @service.save
          render json: @service, status: :created
        else
          render json: { error: @service.errors.full_messages.join(', ') }, status: :unprocessable_entity
        end
      end
      
      # PUT /api/v1/services/:id
      def update
        if @service.update(service_params)
          render json: @service
        else
          render json: { error: @service.errors.full_messages.join(', ') }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/services/:id
      def destroy
        if @service.destroy
          head :no_content
        else
          render json: { error: 'Невозможно удалить услугу, которая используется' }, status: :unprocessable_entity
        end
      end
      
      private
      
      def set_service
        @service = Service.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Услуга не найдена' }, status: :not_found
      end
      
      def service_params
        params.require(:service).permit(:name, :description, :category_id, :default_duration, :is_active, :sort_order)
      end
      
      def authorize_admin!
        unless current_user&.role == 'admin'
          render json: { error: 'Доступ запрещен' }, status: :forbidden
        end
      end
    end
  end
end 