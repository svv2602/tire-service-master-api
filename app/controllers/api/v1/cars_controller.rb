module Api
  module V1
    class CarsController < ApiController
      before_action :set_client
      before_action :set_car, only: [:show, :update, :destroy]
      
      # GET /api/v1/clients/:client_id/cars
      def index
        authorize @client, :show?
        @cars = @client.cars
        
        render json: @cars
      end
      
      # GET /api/v1/clients/:client_id/cars/:id
      def show
        authorize @client, :show?
        render json: @car
      end
      
      # POST /api/v1/clients/:client_id/cars
      def create
        authorize @client, :update?
        
        @car = @client.cars.new(car_params)
        
        if @car.save
          render json: {
            data: @car,
            message: I18n.t('cars.messages.created')
          }, status: :created
        else
          render json: { 
            error: I18n.t('cars.errors.create_failed'),
            details: @car.errors 
          }, status: :unprocessable_entity
        end
      end
      
      # PATCH/PUT /api/v1/clients/:client_id/cars/:id
      def update
        authorize @client, :update?
        
        if @car.update(car_params)
          render json: {
            data: @car,
            message: I18n.t('cars.messages.updated')
          }
        else
          render json: { 
            error: I18n.t('cars.errors.update_failed'),
            details: @car.errors 
          }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/clients/:client_id/cars/:id
      def destroy
        authorize @client, :update?
        
        if @car.bookings.exists?
          # Если есть бронирования с этой машиной, просто помечаем как неактивную
          if @car.update(is_active: false)
            render json: { message: I18n.t('cars.messages.deactivated') }
          else
            render json: { 
              error: I18n.t('cars.errors.deactivate_failed'),
              details: @car.errors 
            }, status: :unprocessable_entity
          end
        else
          # Если бронирований нет, можем полностью удалить
          if @car.destroy
            render json: { message: I18n.t('cars.messages.deleted') }
          else
            render json: { 
              error: I18n.t('cars.errors.delete_failed'),
              details: @car.errors 
            }, status: :unprocessable_entity
          end
        end
      end
      
      private
      
      def set_client
        @client = if current_user.admin? || current_user.partner? || current_user.manager?
                    Client.find(params[:client_id])
                  else
                    current_user.client
                  end
      end
      
      def set_car
        @car = @client.cars.find(params[:id])
      end
      
      def car_params
        params.require(:car).permit(
          :brand_id, :model_id, :car_type_id, :year, :license_plate, :is_primary,
          :registration_number, :tire_r, :tire_width, :tire_height, :name, :is_active
        )
      end
    end
  end
end
