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
        
        Rails.logger.info "BaseController#authenticate_request: Authorization header: #{header}"
        Rails.logger.info "BaseController#authenticate_request: Token from header: #{token}"
        
        # Если токена нет в заголовке, пытаемся получить из encrypted cookies
        if token.blank?
          Rails.logger.info "BaseController#authenticate_request: Trying to get token from cookies"
          Rails.logger.info "BaseController#authenticate_request: Raw access_token cookie: #{request.cookies['access_token']}"
          
          token = cookies.encrypted[:access_token]
          Rails.logger.info "BaseController#authenticate_request: Decrypted token: #{token ? 'present' : 'nil'}"
        end
        
        # Если токен все еще отсутствует, возвращаем ошибку
        if token.blank?
          Rails.logger.error "BaseController#authenticate_request: No token found"
          render json: { error: 'Токен не предоставлен' }, status: :unauthorized
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