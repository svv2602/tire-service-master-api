module Api
  module V1
    class TireTypesController < ApiController
      skip_before_action :authenticate_request
      skip_after_action :verify_authorized
      
      def index
        @tire_types = TireType.active.alphabetical
        render json: {
          tire_types: @tire_types.map { |type| tire_type_json(type) },
          total_items: @tire_types.count
        }
      end
      
      def show
        @tire_type = TireType.find(params[:id])
        render json: tire_type_json(@tire_type)
      end
      
      private
      
      def tire_type_json(tire_type)
        {
          id: tire_type.id,
          name: tire_type.name,
          description: tire_type.description,
          is_active: tire_type.is_active,
          created_at: tire_type.created_at,
          updated_at: tire_type.updated_at
        }
      end
    end
  end
end 