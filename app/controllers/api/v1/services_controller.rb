module Api
  module V1
    class ServicesController < ApiController
      before_action :set_service_category, only: [:index, :create]
      before_action :set_service, only: [:show, :update, :destroy]
      before_action :authorize_admin, except: [:index, :show]
      skip_before_action :authenticate_request, only: [:index, :show]
      
      # GET /api/v1/service_categories/:service_category_id/services
      # GET /api/v1/services
      def index
        @services = if @service_category
          @service_category.services.includes(:category)
        else
          Service.includes(:category)
        end
        
        # Фильтрация активных услуг
        @services = @services.where(is_active: true) if params[:active].present? && params[:active] == 'true'
        
        # Поиск по названию
        if params[:query].present?
          @services = @services.where("LOWER(name) LIKE LOWER(?)", "%#{params[:query]}%")
        end
        
        # Сортировка
        @services = @services.order(params[:sort] || :name)
        
        # Пагинация
        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 10).to_i
        offset = (page - 1) * per_page
        
        total_count = @services.count
        @services = @services.offset(offset).limit(per_page)
        
        render json: {
          data: @services.as_json(include: { category: { only: [:id, :name] } }),
          pagination: {
            current_page: page,
            total_pages: (total_count.to_f / per_page).ceil,
            total_count: total_count,
            per_page: per_page
          }
        }
      end
      
      # GET /api/v1/service_categories/:service_category_id/services/:id
      # GET /api/v1/services/:id
      def show
        render json: @service.as_json(include: { category: { only: [:id, :name] } })
      end
      
      # POST /api/v1/services
      # POST /api/v1/service_categories/:service_category_id/services
      def create
        # Для создания услуги нужна категория
        category_id = params[:service_category_id] || params.dig(:service, :categoryId) || params.dig(:service, :category_id)
        
        unless category_id
          render json: { errors: { category: ['Category is required'] } }, status: :unprocessable_entity
          return
        end
        
        @service_category = ServiceCategory.find(category_id)
        @service = @service_category.services.build(service_params)
        
        if @service.save
          render json: @service.as_json(include: { category: { only: [:id, :name] } }), status: :created
        else
          render json: { errors: @service.errors }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { errors: { category: ['Category not found'] } }, status: :not_found
      end
      
      # PUT /api/v1/service_categories/:service_category_id/services/:id
      def update
        if @service.update(service_params)
          render json: @service.as_json(include: { category: { only: [:id, :name] } })
        else
          render json: { errors: @service.errors }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/service_categories/:service_category_id/services/:id
      def destroy
        if @service.booking_services.exists?
          render json: { error: 'Невозможно удалить услугу, так как она используется в бронированиях' }, status: :unprocessable_entity
        else
          @service.destroy
          head :no_content
        end
      end
      
      private
      
      def set_service_category
        @service_category = ServiceCategory.find(params[:service_category_id]) if params[:service_category_id]
      end
      
      def set_service
        @service = if params[:service_category_id]
          ServiceCategory.find(params[:service_category_id]).services.find(params[:id])
        else
          Service.find(params[:id])
        end
      end
      
      def service_params
        # Поддерживаем как вложенные данные в 'data', так и прямые параметры
        if params[:service][:data].present?
          params.require(:service).require(:data).permit(:name, :description, :default_duration, :is_active, :sort_order)
        else
          params.require(:service).permit(:name, :description, :default_duration, :is_active, :sort_order)
        end
      end
      
      def authorize_admin
        unless current_user && current_user.admin?
          render json: { error: 'Unauthorized' }, status: :unauthorized
        end
      end
    end
  end
end 