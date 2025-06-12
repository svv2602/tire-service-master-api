module Api
  module V1
    class BaseController < ApplicationController
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate_request

      attr_reader :current_user

      private

      def authenticate_request
        header = request.headers['Authorization']
        token = header.split(' ').last if header
        
        begin
          decoded = Auth::JsonWebToken.decode(token)
          @current_user = User.find(decoded['user_id'])
        rescue ActiveRecord::RecordNotFound => e
          render json: { error: 'Пользователь не найден' }, status: :unauthorized
        rescue JWT::DecodeError => e
          render json: { error: 'Неверный токен' }, status: :unauthorized
        end
      end
    end
  end
end 