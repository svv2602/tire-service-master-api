# frozen_string_literal: true

module ApplicationCable
  # WebSocket connection handler with JWT authentication
  # Authenticates users via JWT token passed in query params or cookies
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
      logger.info "[ActionCable] Connected: #{current_user.email}"
    end

    def disconnect
      logger.info "[ActionCable] Disconnected: #{current_user&.email}"
    end

    private

    def find_verified_user
      token = extract_token

      if token.blank?
        logger.warn '[ActionCable] Connection rejected: no token'
        reject_unauthorized_connection
      end

      begin
        decoded = Auth::JsonWebToken.decode(token)
        user = User.find(decoded[:user_id])

        unless user.is_active
          logger.warn "[ActionCable] Connection rejected: user inactive (#{user.id})"
          reject_unauthorized_connection
        end

        user
      rescue Auth::TokenExpiredError
        logger.warn '[ActionCable] Connection rejected: token expired'
        reject_unauthorized_connection
      rescue Auth::TokenInvalidError
        logger.warn '[ActionCable] Connection rejected: invalid token'
        reject_unauthorized_connection
      rescue ActiveRecord::RecordNotFound
        logger.warn '[ActionCable] Connection rejected: user not found'
        reject_unauthorized_connection
      end
    end

    def extract_token
      # Try query params first (WebSocket URL: /cable?token=xxx)
      token = request.params[:token]
      return token if token.present?

      # Try cookies (for browser clients)
      token = cookies[:access_token]
      return token if token.present?

      # Try Authorization header (for some WebSocket clients)
      auth_header = request.headers['Authorization']
      if auth_header.present? && auth_header.start_with?('Bearer ')
        return auth_header.split(' ').last
      end

      nil
    end
  end
end
