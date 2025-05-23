module Api
  module V1
    class AuthController < ApplicationController
      # Пропускаем проверку токена для эндпоинтов логина и обновления токена
      skip_before_action :authenticate_request, only: [:login, :refresh]
      
      # POST /api/v1/auth/login
      # POST /api/v1/authenticate
      def login
        # Extract email and password from params, supporting both formats
        # The test sends params directly at the root level, not nested
        email = params[:email] || (params[:auth] && params[:auth][:email])
        password = params[:password] || (params[:auth] && params[:auth][:password])
        
        auth_service = Auth::Authenticate.new(
          email,
          password,
          ip_address: current_ip,
          user_agent: current_user_agent
        )
        
        tokens = auth_service.call
        
        if tokens
          user = User.find_by(email: email)
          render json: { 
            auth_token: tokens[:access_token], # Changed to match test expectation
            token: tokens[:access_token],      # Keep original key for backward compatibility
            refresh_token: tokens[:refresh_token],
            token_type: tokens[:token_type],
            expires_in: tokens[:expires_in],
            user: UserSerializer.new(user).as_json,
            message: 'Login successful'
          }, status: :ok
        else
          render json: { message: 'Invalid credentials' }, status: :unauthorized
        end
      end
      
      # POST /api/v1/auth/refresh
      def refresh
        refresh_token = params[:refresh_token]
        
        begin
          new_access_token = Auth::JsonWebToken.refresh_access_token(refresh_token)
          render json: {
            auth_token: new_access_token,
            token: new_access_token,
            token_type: 'Bearer',
            expires_in: Auth::JsonWebToken::ACCESS_TOKEN_EXPIRY.to_i,
            message: 'Token refreshed successfully'
          }, status: :ok
        rescue Auth::TokenExpiredError
          render json: { message: 'Refresh token has expired' }, status: :unauthorized
        rescue Auth::TokenInvalidError
          render json: { message: 'Invalid refresh token' }, status: :unauthorized
        rescue Auth::TokenRevokedError
          render json: { message: 'Refresh token has been revoked' }, status: :unauthorized
        end
      end
      
      # POST /api/v1/auth/logout
      def logout
        # Получаем refresh_token из заголовка или параметров
        refresh_token = request.headers['X-Refresh-Token'] || params[:refresh_token]
        
        if refresh_token
          begin
            # Проверяем, что refresh_token действителен и принадлежит текущему пользователю
            decoded_token = Auth::JsonWebToken.decode(refresh_token)
            
            if decoded_token[:user_id] != current_user&.id
              render json: { message: 'Invalid refresh token' }, status: :unauthorized
              return
            end
            
            Auth::JsonWebToken.revoke_refresh_token(decoded_token[:jti])
            render json: { message: 'Successfully logged out' }, status: :ok
          rescue StandardError => e
            Rails.logger.error("Error during logout: #{e.message}")
            render json: { message: 'Invalid refresh token' }, status: :unauthorized
          end
        else
          render json: { message: 'Refresh token is required' }, status: :bad_request
        end
      end
      
      private
      
      def auth_params
        params.require(:auth).permit(:email, :password)
      rescue ActionController::ParameterMissing
        # If auth params are not nested, use the root params
        params.permit(:email, :password)
      end
    end
  end
end
