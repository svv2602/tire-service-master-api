module Api
  module V1
    class CarTypesController < ApiController
      # GET /api/v1/car_types
      def index
        @car_types = CarType.active.alphabetical
        render json: @car_types
      end

      # GET /api/v1/car_types/:id
      def show
        @car_type = CarType.find(params[:id])
        render json: @car_type
      end
    end
  end
end
