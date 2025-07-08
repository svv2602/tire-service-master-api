module Api
  module V1
    class CarTypesController < ApiController
      # Разрешаем публичный доступ к чтению типов автомобилей для клиентских бронирований
      skip_before_action :authenticate_request, only: [:index, :show]
      
      # GET /api/v1/car_types
      def index
        @car_types = CarType.active.alphabetical
        render json: @car_types, each_serializer: CarTypeSerializer, locale: current_locale
      end

      # GET /api/v1/car_types/:id
      def show
        @car_type = CarType.find(params[:id])
        render json: @car_type, serializer: CarTypeSerializer, locale: current_locale
      end
      
      private
      
      def current_locale
        # Получаем локаль из заголовка Accept-Language или параметра locale
        locale_from_header = request.headers['Accept-Language']&.split(',')&.first&.split('-')&.first
        requested_locale = params[:locale] || locale_from_header || 'ru'
        
        # Проверяем, что локаль поддерживается
        %w[ru uk].include?(requested_locale) ? requested_locale : 'ru'
      end
    end
  end
end
