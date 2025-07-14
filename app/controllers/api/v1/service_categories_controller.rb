module Api
  module V1
    class ServiceCategoriesController < ApiController
      skip_before_action :authenticate_request, only: [:index, :show, :by_city, :by_city_id]
      before_action :set_service_category, only: [:show, :update, :destroy]
      before_action :authorize_admin!, only: [:create, :update, :destroy]
      
      # GET /api/v1/service_categories
      def index
        # Определяем язык из параметров или заголовков
        locale = params[:locale] || request.headers['Accept-Language']&.split(',')&.first || 'ru'
        
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
        
        # Фильтрация только категорий с активными постами
        if params[:with_active_posts] == 'true'
          @service_categories = @service_categories
            .joins("INNER JOIN service_posts ON service_posts.service_category_id = service_categories.id")
            .joins("INNER JOIN service_points ON service_points.id = service_posts.service_point_id")
            .where("service_posts.is_active = true")
            .where("service_points.is_active = true")
            .distinct
        end
        
        # Поиск по названию (учитываем локализацию)
        if params[:query].present?
          query = params[:query].downcase
          @service_categories = @service_categories.where(
            "LOWER(name) LIKE ? OR LOWER(name_uk) LIKE ? OR LOWER(description) LIKE ? OR LOWER(description_uk) LIKE ?",
            "%#{query}%", "%#{query}%", "%#{query}%", "%#{query}%"
          )
        end
        
        # Сортировка
        @service_categories = @service_categories.order(params[:sort] || :name)
        
        # Пагинация
        page = [params[:page].to_i, 1].max  # Минимум 1
        per_page = (params[:per_page] || 25).to_i
        offset = (page - 1) * per_page
        
        total_count = @service_categories.count
        @service_categories = @service_categories.offset(offset).limit(per_page)
        
        render json: {
          data: ActiveModel::Serializer::CollectionSerializer.new(
            @service_categories,
            serializer: ServiceCategorySerializer,
            locale: locale,
            include_services_count: true
          ),
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
        locale = params[:locale] || request.headers['Accept-Language']&.split(',')&.first || 'ru'
        render json: category_json(@service_category, include_services: true, locale: locale)
      end

      # GET /api/v1/service_categories/by_city/:city_name
      def by_city
        city_name = params[:city_name]
        locale = params[:locale] || request.headers['Accept-Language']&.split(',')&.first || 'ru'
        
        # Ищем город по имени (учитываем локализацию)
        city = City.where(
          "LOWER(name) = ? OR LOWER(name_ru) = ? OR LOWER(name_uk) = ?",
          city_name.downcase, city_name.downcase, city_name.downcase
        ).first
        
        unless city
          render json: { error: 'Город не найден' }, status: :not_found
          return
        end
        
        # Получаем категории услуг, доступные в этом городе
        @service_categories = ServiceCategory.joins(:service_posts)
                                           .joins("INNER JOIN service_points ON service_points.id = service_posts.service_point_id")
                                           .where("service_points.city_id = ? AND service_points.is_active = true", city.id)
                                           .where("service_posts.is_active = true")
                                           .distinct
                                           .order(:name)
        
        categories_with_stats = @service_categories.map do |category|
          # Подсчет сервисных точек для категории в данном городе
          service_points_count = ServicePoint
            .joins(:service_posts)
            .where("service_points.city_id = ? AND service_points.is_active = true", city.id)
            .where("service_posts.service_category_id = ? AND service_posts.is_active = true", category.id)
            .distinct
            .count

          # Подсчет услуг для категории в данном городе (через service_point_services)
          services_count = Service
            .joins(:service_point_services)
            .joins("INNER JOIN service_points ON service_points.id = service_point_services.service_point_id")
            .where("service_points.city_id = ? AND service_points.is_active = true", city.id)
            .where("services.category_id = ?", category.id)
            .where("service_point_services.is_available = true")
            .distinct
            .count

          ServiceCategorySerializer.new(category, locale: locale).as_json.merge({
            'service_points_count' => service_points_count,
            'services_count' => services_count,
            'city_name' => city.localized_name(locale)
          })
        end

        render json: {
          data: categories_with_stats,
          city: {
            id: city.id,
            name: city.localized_name(locale),
            region: city.region&.localized_name(locale)
          },
          total_count: categories_with_stats.length
        }
      end
      
      # GET /api/v1/service_categories/by_city_id/:city_id
      def by_city_id
        city_id = params[:city_id]
        locale = params[:locale] || request.headers['Accept-Language']&.split(',')&.first || 'ru'
        
        city = City.find_by(id: city_id)
        unless city
          render json: { error: 'Город не найден' }, status: :not_found
          return
        end
        
        # Получаем категории услуг, доступные в этом городе
        @service_categories = ServiceCategory.joins(:service_posts)
                                           .joins("INNER JOIN service_points ON service_points.id = service_posts.service_point_id")
                                           .where("service_points.city_id = ? AND service_points.is_active = true", city.id)
                                           .where("service_posts.is_active = true")
                                           .distinct
                                           .order(:name)
        
        categories_with_stats = @service_categories.map do |category|
          # Подсчет сервисных точек для категории в данном городе
          service_points_count = ServicePoint
            .joins(:service_posts)
            .where("service_points.city_id = ? AND service_points.is_active = true", city.id)
            .where("service_posts.service_category_id = ? AND service_posts.is_active = true", category.id)
            .distinct
            .count

          # Подсчет услуг для категории в данном городе (через service_point_services)
          services_count = Service
            .joins(:service_point_services)
            .joins("INNER JOIN service_points ON service_points.id = service_point_services.service_point_id")
            .where("service_points.city_id = ? AND service_points.is_active = true", city.id)
            .where("services.category_id = ?", category.id)
            .where("service_point_services.is_available = true")
            .distinct
            .count

          ServiceCategorySerializer.new(category, locale: locale).as_json.merge({
            'service_points_count' => service_points_count,
            'services_count' => services_count,
            'city_name' => city.localized_name(locale)
          })
        end

        render json: {
          data: categories_with_stats,
          city: {
            id: city.id,
            name: city.localized_name(locale),
            region: city.region&.localized_name(locale)
          },
          total_count: categories_with_stats.length
        }
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
        params.require(:service_category).permit(:name, :name_uk, :description, :description_uk, :is_active, :sort_order)
      end
      
      def authorize_admin!
        unless current_user && current_user.admin?
          render json: { error: 'Forbidden' }, status: :forbidden
        end
      end
      
      def category_json(category, include_services: false, locale: 'ru')
        json = ServiceCategorySerializer.new(category, locale: locale, include_services_count: true).as_json
        if include_services
          json['services'] = ActiveModel::Serializer::CollectionSerializer.new(
            category.services,
            serializer: ServiceSerializer,
            locale: locale
          )
        end
        json
      end
    end
  end
end 