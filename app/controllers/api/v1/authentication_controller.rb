# DEPRECATED: This controller is not mounted in routes.
# Use AuthController (api/v1/auth_controller.rb) for all authentication.
# Kept for backward compatibility only. Will be removed in a future release.
module Api
  module V1
    class AuthenticationController < ApplicationController
      skip_after_action :verify_authorized
      skip_before_action :authenticate_request

      def authenticate
        user = User.find_by(email: params[:email])

        if user&.authenticate(params[:password])
          unless user.is_active?
            render json: { error: I18n.t('auth.errors.account_blocked', default: 'Account is blocked') }, status: :forbidden
            return
          end

          access_token = Auth::JsonWebToken.encode_access_token(user_id: user.id)
          refresh_token = Auth::JsonWebToken.encode_refresh_token(user_id: user.id)

          # Set refresh token in HttpOnly cookie (never in JSON body)
          cookies[:refresh_token] = {
            value: refresh_token,
            httponly: true,
            secure: Rails.env.production?,
            same_site: :lax,
            expires: 30.days.from_now,
            path: '/'
          }

          # Set access token in HttpOnly cookie
          cookies[:access_token] = {
            value: access_token,
            httponly: true,
            secure: Rails.env.production?,
            same_site: :lax,
            expires: 1.hour.from_now,
            path: '/'
          }

          render json: {
            tokens: {
              access: access_token
              # Refresh token is in HttpOnly cookie only -- not in JSON body
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
          # Read refresh token from HttpOnly cookie (fallback to header for backward compatibility)
          refresh_token = cookies[:refresh_token] || request.headers['Refresh-Token']
          raise Auth::TokenInvalidError, I18n.t('auth.errors.token_required') if refresh_token.blank?

          access_token = Auth::JsonWebToken.refresh_access_token(refresh_token)

          # Update access token cookie
          cookies[:access_token] = {
            value: access_token,
            httponly: true,
            secure: Rails.env.production?,
            same_site: :lax,
            expires: 1.hour.from_now,
            path: '/'
          }

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
