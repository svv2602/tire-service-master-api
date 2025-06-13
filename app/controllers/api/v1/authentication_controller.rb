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
            }
          }
        else
          render json: { message: 'Invalid credentials' }, status: :unauthorized
        end
      end

      def refresh
        begin
          refresh_token = request.headers['Refresh-Token']
          raise Auth::TokenInvalidError, 'Refresh token is required' if refresh_token.blank?
          
          access_token = Auth::JsonWebToken.refresh_access_token(refresh_token)
          render json: { access_token: access_token }
        rescue Auth::TokenExpiredError, Auth::TokenInvalidError, Auth::TokenRevokedError => e
          render json: { error: e.message }, status: :unauthorized
        end
      end
    end
  end
end 