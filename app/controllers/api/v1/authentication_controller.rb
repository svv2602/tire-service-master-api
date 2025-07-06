module Api
  module V1
    class AuthenticationController < ApplicationController
      skip_before_action :authenticate_request

      def authenticate
        user = User.find_by(email: params[:email])
        
        if user&.authenticate(params[:password])
          access_token = Auth::JsonWebToken.encode_access_token(user_id: user.id)
          refresh_token = Auth::JsonWebToken.encode_refresh_token(user_id: user.id)
          
          render json: {
            tokens: {
              access: access_token,
              refresh: refresh_token
            },
            user: {
              id: user.id,
              email: user.email,
              first_name: user.first_name,
              last_name: user.last_name,
              role: user.role.name
            },
            message: I18n.t('auth.messages.login_success')
          }
        else
          render json: { error: I18n.t('auth.errors.invalid_credentials') }, status: :unauthorized
        end
      end

      def refresh
        begin
          refresh_token = request.headers['Refresh-Token']
          raise Auth::TokenInvalidError, I18n.t('auth.errors.token_required') if refresh_token.blank?
          
          access_token = Auth::JsonWebToken.refresh_access_token(refresh_token)
          render json: { access_token: access_token }
        rescue Auth::TokenExpiredError
          render json: { error: I18n.t('auth.errors.token_expired') }, status: :unauthorized
        rescue Auth::TokenInvalidError
          render json: { error: I18n.t('auth.errors.token_invalid') }, status: :unauthorized
        rescue Auth::TokenRevokedError
          render json: { error: I18n.t('auth.errors.token_revoked') }, status: :unauthorized
        end
      end
    end
  end
end 