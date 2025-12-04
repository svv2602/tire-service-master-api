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

        # Security: log only presence, never token values
        Rails.logger.debug "Auth: header=#{header.present?}, token=#{token.present?}"

        # Если токена нет в заголовке, пытаемся получить из cookies (обычных, не encrypted)
        if token.blank?
          token = cookies[:access_token]
          Rails.logger.debug "Auth: token_from_cookie=#{token.present?}"
        end

        # Если токен все еще отсутствует, возвращаем ошибку
        if token.blank?
          Rails.logger.debug "Auth: no token found"
          render json: { error: 'Токен не предоставлен' }, status: :unauthorized
          return
        end

        begin
          decoded = Auth::JsonWebToken.decode(token)
          @current_user = User.find(decoded['user_id'])
          Rails.logger.debug "Auth: authenticated user_id=#{@current_user.id}"
        rescue ActiveRecord::RecordNotFound => e
          render json: { error: 'Пользователь не найден' }, status: :unauthorized
        rescue Auth::TokenExpiredError => e
          render json: { error: 'Токен истек' }, status: :unauthorized
        rescue Auth::TokenInvalidError => e
          render json: { error: 'Неверный токен' }, status: :unauthorized
        rescue JWT::DecodeError => e
          render json: { error: 'Неверный токен' }, status: :unauthorized
        end
      end

      def ensure_admin!
        unless current_user&.admin?
          render json: { error: 'Доступ запрещен' }, status: :forbidden
        end
      end
    end
  end
end 