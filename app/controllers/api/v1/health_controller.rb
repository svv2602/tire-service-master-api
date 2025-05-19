module Api
  module V1
    class HealthController < ApplicationController
      # Пропускаем проверку токена для этого эндпоинта
      skip_before_action :authenticate_request, only: [:index]
      
      # GET /api/v1/health
      def index
        render json: { status: 'ok', timestamp: Time.current }, status: :ok
      end
    end
  end
end 