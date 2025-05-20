module Api
  module V1
    class CitiesController < ApiController
      before_action :set_city, only: [:show, :update, :destroy]
      before_action :authorize_admin, except: [:index, :show]
      skip_before_action :authenticate_request, only: [:index, :show]
      
      # GET /api/v1/cities
      def index
        @cities = City.includes(:region)
        
        # Фильтрация по региону
        @cities = @cities.where(region_id: params[:region_id]) if params[:region_id].present?
        
        # Фильтрация активных городов
        @cities = @cities.where(is_active: true) if params[:active].present? && params[:active] == 'true'
        
        # Поиск по названию
        if params[:query].present?
          @cities = @cities.where("name LIKE ?", "%#{params[:query]}%")
        end
        
        # Сортировка
        @cities = @cities.order(params[:sort] || :name)
        
        # Пагинация
        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 25).to_i
        offset = (page - 1) * per_page
        
        total_count = @cities.count
        @cities = @cities.offset(offset).limit(per_page)
        
        render json: {
          cities: @cities.as_json(include: { region: { only: [:id, :name] } }),
          total_items: total_count
        }
      end
      
      # GET /api/v1/cities/:id
      def show
        render json: @city.as_json(include: { region: { only: [:id, :name] } })
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