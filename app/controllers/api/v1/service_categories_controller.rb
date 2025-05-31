module Api
  module V1
    class ServiceCategoriesController < ApiController
      skip_before_action :authenticate_request, only: [:index, :show]
      before_action :set_service_category, only: [:show, :update, :destroy]
      before_action :authorize_admin!, only: [:create, :update, :destroy]
      
      # GET /api/v1/service_categories
      def index
        @service_categories = ServiceCategory.all
        
        # Фильтрация: по умолчанию показываем только активные, если не указано иначе
        if params[:active] == 'false'
          # Показать неактивные категории
          @service_categories = @service_categories.where(is_active: false)
        elsif params[:active] == 'all'
          # Показать все категории (активные и неактивные)
          # @service_categories остается без изменений
        else
          # По умолчанию показываем только активные
          @service_categories = @service_categories.where(is_active: true)
        end
        
        # Поиск по названию
        if params[:query].present?
          @service_categories = @service_categories.where("LOWER(name) LIKE LOWER(?)", "%#{params[:query]}%")
        end
        
        # Сортировка
        @service_categories = @service_categories.order(params[:sort] || :name)
        
        # Пагинация
        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 25).to_i
        offset = (page - 1) * per_page
        
        total_count = @service_categories.count
        @service_categories = @service_categories.offset(offset).limit(per_page)
        
        render json: {
          data: @service_categories.as_json(include_services_count: true),
          pagination: {
            current_page: page,
            total_pages: (total_count.to_f / per_page).ceil,
            total_count: total_count,
            per_page: per_page
          }
        }
      end
      
      # GET /api/v1/service_categories/:id
      def show
        render json: category_json(@service_category, include_services: true)
      end
      
      # POST /api/v1/service_categories
      def create
        @service_category = ServiceCategory.new(service_category_params)
        
        if @service_category.save
          render json: category_json(@service_category), status: :created
        else
          render json: { errors: @service_category.errors }, status: :unprocessable_entity
        end
      end
      
      # PUT /api/v1/service_categories/:id
      def update
        if @service_category.update(service_category_params)
          render json: category_json(@service_category)
        else
          render json: { errors: @service_category.errors }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/service_categories/:id
      def destroy
        if @service_category.services.exists?
          render json: { error: 'Невозможно удалить категорию, так как она содержит услуги' }, status: :unprocessable_entity
        else
          @service_category.destroy
          head :no_content
        end
      end
      
      private
      
      def set_service_category
        @service_category = ServiceCategory.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Категория услуг не найдена' }, status: :not_found
      end
      
      def service_category_params
        params.require(:service_category).permit(:name, :description, :is_active, :sort_order)
      end
      
      def authorize_admin!
        unless current_user && current_user.admin?
          render json: { error: 'Forbidden' }, status: :forbidden
        end
      end
      
      def category_json(category, include_services: false)
        json = category.as_json(include_services_count: true)
        if include_services
          json['services'] = category.services.as_json(include: :category)
        end
        json
      end
    end
  end
end 