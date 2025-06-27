module Api
  module V1
    class CitiesController < ApiController
      before_action :set_city, only: [:show, :update, :destroy]
      before_action :authorize_admin, except: [:index, :show, :with_service_points]
      skip_before_action :authenticate_request, only: [:index, :show, :with_service_points]
      
      # GET /api/v1/cities
      def index
        cities = City.includes(:region)
                     .where(is_active: true)
        
        # Фильтрация по region_id если параметр передан
        if params[:region_id].present?
          cities = cities.where(region_id: params[:region_id])
        end
        
        cities = cities.order(:name)

        # Пагинация
        page = params[:page]&.to_i || 1
        per_page = params[:per_page]&.to_i || 20
        per_page = [per_page, 100].min # Ограничиваем максимум 100 записей на страницу
        
        offset = (page - 1) * per_page
        total_count = cities.count
        cities = cities.limit(per_page).offset(offset)

        render json: {
          data: cities.map do |city|
            {
              id: city.id,
              name: city.name,
              region_id: city.region_id,
              region_name: city.region.name,
              is_active: city.is_active
            }
          end,
          total: total_count,
          page: page,
          per_page: per_page,
          total_pages: (total_count.to_f / per_page).ceil
        }
      end
      
      # GET /api/v1/cities/with_service_points
      def with_service_points
        cities = City.joins(:service_points)
                     .where(is_active: true, service_points: { is_active: true, work_status: 'working' })
                     .includes(:region)
                     .distinct
                     .order(:name)

        render json: {
          data: cities.map do |city|
            service_points_count = city.service_points.where(is_active: true, work_status: 'working').count
            
            {
              id: city.id,
              name: city.name,
              region_id: city.region_id,
              region: {
                id: city.region.id,
                name: city.region.name,
                code: city.region.code
              },
              service_points_count: service_points_count,
              is_active: city.is_active
            }
          end,
          total: cities.count
        }
      end
      
      # GET /api/v1/cities/:id
      def show
        city = City.includes(:region, :service_points).find(params[:id])
        
        render json: {
          data: {
            id: city.id,
            name: city.name,
            region_id: city.region_id,
            region: {
              id: city.region.id,
              name: city.region.name,
              code: city.region.code
            },
            service_points_count: city.service_points.where(is_active: true).count,
            is_active: city.is_active
          }
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Город не найден' }, status: :not_found
      end
      
      # POST /api/v1/cities
      def create
        @city = City.new(city_params)
        
        if @city.save
          render json: @city.as_json(include: { region: { only: [:id, :name] } }), status: :created
        else
          render json: { errors: @city.errors }, status: :unprocessable_entity
        end
      end
      
      # PUT /api/v1/cities/:id
      def update
        if @city.update(city_params)
          render json: @city.as_json(include: { region: { only: [:id, :name] } })
        else
          render json: { errors: @city.errors }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/cities/:id
      def destroy
        if @city.service_points.exists?
          render json: { error: 'Невозможно удалить город, так как в нем есть сервисные точки' }, status: :unprocessable_entity
        else
          @city.destroy
          head :no_content
        end
      end
      
      private
      
      def set_city
        @city = City.find(params[:id])
      end
      
      def city_params
        params.require(:city).permit(:name, :region_id, :is_active)
      end
      
      def authorize_admin
        unless current_user && current_user.admin?
          render json: { error: 'Unauthorized' }, status: :unauthorized
        end
      end
    end
  end
end 