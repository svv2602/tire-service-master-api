module Api
  module V1
    class AuthenticationController < ApplicationController
      skip_before_action :authenticate_request

      def authenticate
        user = User.find_by(email: params[:email])
        
        if user&.authenticate(params[:password])
          token = Auth::JsonWebToken.encode_access_token(user_id: user.id)
          render json: { auth_token: token }
        else
          render json: { message: 'Invalid credentials' }, status: :unauthorized
        end
      end
    end
  end
end 