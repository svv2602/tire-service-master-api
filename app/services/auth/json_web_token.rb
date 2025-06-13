module Auth
  class JsonWebToken
    # Секрет для подписи JWT токенов
    SECRET_KEY = ENV['JWT_SECRET_KEY'] || Rails.application.secret_key_base
    
    # Время жизни токенов
    ACCESS_TOKEN_EXPIRY = 24.hours  # Увеличиваем до 24 часов
    REFRESH_TOKEN_EXPIRY = 30.days
    
    class << self
      def encode_access_token(payload)
        Rails.logger.info("Encoding access token for payload: #{payload}")
        payload[:exp] = ACCESS_TOKEN_EXPIRY.from_now.to_i
        payload[:token_type] = 'access'
        payload[:iat] = Time.current.to_i
        token = JWT.encode(payload, SECRET_KEY)
        Rails.logger.info("Successfully encoded access token")
        token
      end
      
      def encode_refresh_token(payload)
        Rails.logger.info("Encoding refresh token for payload: #{payload}")
        payload[:exp] = REFRESH_TOKEN_EXPIRY.from_now.to_i
        payload[:token_type] = 'refresh'
        payload[:jti] = SecureRandom.uuid
        payload[:iat] = Time.current.to_i
        token = JWT.encode(payload, SECRET_KEY)
        Rails.logger.info("Successfully encoded refresh token with jti: #{payload[:jti]}")
        token
      end
      
      def decode(token)
        Rails.logger.info("Decoding token: #{token.to_s[0..10]}...")
        Rails.logger.debug("Using secret key: #{SECRET_KEY}")
        
        begin
          decoded = JWT.decode(token, SECRET_KEY, true, {
            algorithm: 'HS256',
            verify_expiration: true,
            verify_iat: true,
            required_claims: ['exp', 'token_type', 'iat']
          })[0]
          
          Rails.logger.info("Successfully decoded token. Type: #{decoded['token_type']}, User ID: #{decoded['user_id']}")
          HashWithIndifferentAccess.new(decoded)
        rescue JWT::ExpiredSignature => e
          Rails.logger.error("JWT expired signature error: #{e.message}")
          raise TokenExpiredError, 'Token has expired'
        rescue JWT::DecodeError => e
          Rails.logger.error("JWT decode error: #{e.message}")
          raise TokenInvalidError, 'Token is invalid'
        rescue JWT::VerificationError => e
          Rails.logger.error("JWT verification error: #{e.message}")
          raise TokenInvalidError, 'Token verification failed'
        end
      end
      
      def refresh_access_token(refresh_token)
        Rails.logger.info("Refreshing access token with refresh token: #{refresh_token.to_s[0..10]}...")
        decoded_refresh_token = decode(refresh_token)
        
        # Проверяем, что это refresh token
        unless decoded_refresh_token[:token_type] == 'refresh'
          Rails.logger.error("Invalid token type: #{decoded_refresh_token[:token_type]}")
          raise TokenInvalidError, 'Invalid token type'
        end
        
        # Проверяем, не был ли токен отозван
        if token_revoked?(decoded_refresh_token[:jti])
          Rails.logger.error("Token has been revoked: #{decoded_refresh_token[:jti]}")
          raise TokenRevokedError, 'Token has been revoked'
        end
        
        # Создаем новый access token
        Rails.logger.info("Creating new access token for user: #{decoded_refresh_token[:user_id]}")
        encode_access_token(user_id: decoded_refresh_token[:user_id])
      end
      
      def revoke_refresh_token(jti)
        Rails.logger.info("Revoking refresh token: #{jti}")
        Rails.cache.write("revoked_token:#{jti}", true, expires_in: REFRESH_TOKEN_EXPIRY)
        Rails.logger.info("Successfully revoked refresh token: #{jti}")
      end
      
      private
      
      def token_revoked?(jti)
        revoked = Rails.cache.exist?("revoked_token:#{jti}")
        Rails.logger.info("Checking if token is revoked: #{jti}, Result: #{revoked}")
        revoked
      end
    end
  end
  
  # Исключения для обработки ошибок токена
  class TokenExpiredError < StandardError; end
  class TokenInvalidError < StandardError; end
  class TokenRevokedError < StandardError; end
end
