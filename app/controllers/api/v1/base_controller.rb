module Api
  module V1
    class BaseController < ApplicationController
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate_request

      attr_reader :current_user

      private

      def authenticate_request
        # Пытаемся получить токен из заголовка Authorization
        header = request.headers['Authorization']
        token = header.split(' ').last if header
        
        # Если токена нет в заголовке, пытаемся получить из encrypted cookies
        if token.blank?
          token = cookies.encrypted[:access_token]
        end
        
        # Если токен все еще отсутствует, возвращаем ошибку
        if token.blank?
          render json: { error: 'Токен отсутствует' }, status: :unauthorized
          return
        end
        
        begin
          decoded = Auth::JsonWebToken.decode(token)
          @current_user = User.find(decoded['user_id'])
        rescue ActiveRecord::RecordNotFound => e
          render json: { error: 'Пользователь не найден' }, status: :unauthorized
        rescue JWT::DecodeError => e
          render json: { error: 'Неверный токен' }, status: :unauthorized
        rescue Auth::TokenInvalidError => e
          render json: { error: 'Неверный токен' }, status: :unauthorized
        end
      end
    end
  end
end 