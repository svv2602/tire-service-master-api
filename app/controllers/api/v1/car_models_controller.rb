module Api
  module V1
    class CarModelsController < ApiController
      before_action :set_car_model, only: [:show, :update, :destroy]
      before_action :authorize_admin, except: [:index, :show]
      skip_before_action :authenticate_request, only: [:index, :show]
      
      # GET /api/v1/car_models
      def index
        @car_models = CarModel.includes(:brand)
        
        # Фильтрация по бренду
        @car_models = @car_models.where(brand_id: params[:brand_id]) if params[:brand_id].present?
        
        # Фильтрация активных моделей
        @car_models = @car_models.where(is_active: true) if params[:active].present? && params[:active] == 'true'
        
        # Поиск по названию
        if params[:query].present?
          @car_models = @car_models.where("name LIKE ?", "%#{params[:query]}%")
        end
        
        # Сортировка
        @car_models = @car_models.order(params[:sort] || :name)
        
        # Пагинация
        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 25).to_i
        offset = (page - 1) * per_page
        
        total_count = @car_models.count
        @car_models = @car_models.offset(offset).limit(per_page)
        
        render json: {
          car_models: @car_models.as_json(include: { brand: { only: [:id, :name] } }),
          total_items: total_count
        }
      end
      
      # GET /api/v1/car_models/:id
      def show
        render json: @car_model.as_json(include: { brand: { only: [:id, :name] } })
      end
      
      # POST /api/v1/car_models
      def create
        @car_model = CarModel.new(car_model_params)
        
        if @car_model.save
          render json: @car_model.as_json(include: { brand: { only: [:id, :name] } }), status: :created
        else
          render json: { errors: @car_model.errors }, status: :unprocessable_entity
        end
      end
      
      # PUT /api/v1/car_models/:id
      def update
        if @car_model.update(car_model_params)
          render json: @car_model.as_json(include: { brand: { only: [:id, :name] } })
        else
          render json: { errors: @car_model.errors }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/car_models/:id
      def destroy
        if @car_model.client_cars.exists?
          render json: { error: 'Невозможно удалить модель, так как она используется в автомобилях клиентов' }, status: :unprocessable_entity
        else
          @car_model.destroy
          head :no_content
        end
      end
      
      private
      
      def set_car_model
        @car_model = CarModel.find(params[:id])
      end
      
      def car_model_params
        params.require(:car_model).permit(:name, :brand_id, :is_active)
      end
      
      def authorize_admin
        unless current_user && current_user.admin?
          render json: { error: 'Unauthorized' }, status: :unauthorized
        end
      end
    end
  end
end 