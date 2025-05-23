module Auth
  class JsonWebToken
    # Секрет для подписи JWT токенов
    SECRET_KEY = ENV['JWT_SECRET_KEY'] || Rails.application.secret_key_base
    
    # Время жизни токенов
    ACCESS_TOKEN_EXPIRY = 1.hour
    REFRESH_TOKEN_EXPIRY = 30.days
    
    class << self
      def encode_access_token(payload)
        payload[:exp] = ACCESS_TOKEN_EXPIRY.from_now.to_i
        payload[:token_type] = 'access'
        JWT.encode(payload, SECRET_KEY)
      end
      
      def encode_refresh_token(payload)
        payload[:exp] = REFRESH_TOKEN_EXPIRY.from_now.to_i
        payload[:token_type] = 'refresh'
        payload[:jti] = SecureRandom.uuid # Уникальный идентификатор для отзыва токена
        JWT.encode(payload, SECRET_KEY)
      end
      
      def decode(token)
        Rails.logger.info("Trying to decode token: #{token}")
        Rails.logger.info("Using secret key: #{SECRET_KEY}")
        
        begin
          decoded = JWT.decode(token, SECRET_KEY, true, {
            algorithm: 'HS256',
            verify_expiration: true,
            verify_iat: true,
            required_claims: ['exp', 'token_type']
          })[0]
          
          Rails.logger.info("Successfully decoded token: #{decoded}")
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
        decoded_refresh_token = decode(refresh_token)
        
        # Проверяем, что это refresh token
        raise TokenInvalidError, 'Invalid token type' unless decoded_refresh_token[:token_type] == 'refresh'
        
        # Проверяем, не был ли токен отозван
        raise TokenRevokedError, 'Token has been revoked' if token_revoked?(decoded_refresh_token[:jti])
        
        # Создаем новый access token
        encode_access_token(user_id: decoded_refresh_token[:user_id])
      end
      
      def revoke_refresh_token(jti)
        Rails.cache.write("revoked_token:#{jti}", true, expires_in: REFRESH_TOKEN_EXPIRY)
      end
      
      private
      
      def token_revoked?(jti)
        Rails.cache.exist?("revoked_token:#{jti}")
      end
    end
  end
  
  # Исключения для обработки ошибок токена
  class TokenExpiredError < StandardError; end
  class TokenInvalidError < StandardError; end
  class TokenRevokedError < StandardError; end
end
