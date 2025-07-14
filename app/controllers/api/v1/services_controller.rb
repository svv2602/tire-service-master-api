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
        # Определяем язык из параметров или заголовков
        locale = params[:locale] || request.headers['Accept-Language']&.split(',')&.first || 'ru'
        
        @services = if @service_category
          @service_category.services.includes(:category)
        else
          Service.includes(:category)
        end
        
        # Фильтрация по category_id (если передан параметр)
        if params[:category_id].present?
          @services = @services.where(category_id: params[:category_id])
        end
        
        # Фильтрация активных услуг
        @services = @services.where(is_active: true) if params[:active].present? && params[:active] == 'true'
        
        # Поиск по названию (учитываем локализацию)
        if params[:query].present?
          query = params[:query].downcase
          @services = @services.where(
            "LOWER(name) LIKE ? OR LOWER(name_uk) LIKE ? OR LOWER(description) LIKE ? OR LOWER(description_uk) LIKE ?",
            "%#{query}%", "%#{query}%", "%#{query}%", "%#{query}%"
          )
        end
        
        # Сортировка
        @services = @services.order(params[:sort] || :name)
        
        # Пагинация
        page = [params[:page].to_i, 1].max  # Минимум 1
        per_page = (params[:per_page] || 10).to_i
        offset = (page - 1) * per_page
        
        total_count = @services.count
        @services = @services.offset(offset).limit(per_page)
        
        render json: {
          data: ActiveModel::Serializer::CollectionSerializer.new(
            @services,
            serializer: ServiceSerializer,
            locale: locale,
            include: { category: { only: [:id, :name, :name_uk, :localized_name] } }
          ),
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
        locale = params[:locale] || request.headers['Accept-Language']&.split(',')&.first || 'ru'
        render json: ServiceSerializer.new(@service, locale: locale, include: { category: { only: [:id, :name, :name_uk, :localized_name] } })
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
          locale = params[:locale] || request.headers['Accept-Language']&.split(',')&.first || 'ru'
          render json: ServiceSerializer.new(@service, locale: locale, include: { category: { only: [:id, :name, :name_uk, :localized_name] } }), status: :created
        else
          render json: { errors: @service.errors }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { errors: { category: ['Category not found'] } }, status: :not_found
      end
      
      # PUT /api/v1/service_categories/:service_category_id/services/:id
      def update
        if @service.update(service_params)
          locale = params[:locale] || request.headers['Accept-Language']&.split(',')&.first || 'ru'
          render json: ServiceSerializer.new(@service, locale: locale, include: { category: { only: [:id, :name, :name_uk, :localized_name] } })
        else
          render json: { errors: @service.errors }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/service_categories/:service_category_id/services/:id
      def destroy
        @service.destroy
        head :no_content
      end
      
      private
      
      def set_service_category
        return unless params[:service_category_id]
        @service_category = ServiceCategory.find(params[:service_category_id])
      rescue ActiveRecord::RecordNotFound
        render json: { errors: { category: ['Category not found'] } }, status: :not_found
      end
      
      def set_service
        @service = Service.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { errors: { service: ['Service not found'] } }, status: :not_found
      end
      
      def service_params
        params.require(:service).permit(:name, :name_uk, :description, :description_uk, :is_active, :sort_order)
      end
      
      def authorize_admin
        unless current_user && current_user.admin?
          render json: { error: 'Forbidden' }, status: :forbidden
        end
      end
    end
  end
end 