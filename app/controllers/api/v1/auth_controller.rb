module Api
  module V1
    class AuthController < ApplicationController
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
        
        token = auth_service.call
        
        if token
          user = User.find_by(email: email)
          render json: { 
            auth_token: token, # Changed to match test expectation
            token: token,      # Keep original key for backward compatibility  
            user: UserSerializer.new(user).as_json,
            message: 'Login successful'
          }, status: :ok
        else
          render json: { message: 'Invalid credentials' }, status: :unauthorized
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
