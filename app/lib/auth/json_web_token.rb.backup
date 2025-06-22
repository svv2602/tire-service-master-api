module Auth
  class TokenExpiredError < StandardError; end
  class TokenInvalidError < StandardError; end
  class TokenRevokedError < StandardError; end

  class JsonWebToken
    SECRET_KEY = Rails.application.credentials.secret_key_base
    ACCESS_TOKEN_EXPIRY = 24.hours
    REFRESH_TOKEN_EXPIRY = 30.days

    def self.encode_access_token(payload)
      payload = payload.dup
      payload[:exp] = ACCESS_TOKEN_EXPIRY.from_now.to_i
      payload[:token_type] = 'access'
      JWT.encode(payload, SECRET_KEY)
    end

    def self.encode_refresh_token(payload)
      payload = payload.dup
      payload[:exp] = REFRESH_TOKEN_EXPIRY.from_now.to_i
      payload[:token_type] = 'refresh'
      JWT.encode(payload, SECRET_KEY)
    end

    def self.decode(token)
      decoded = JWT.decode(token, SECRET_KEY)[0]
      HashWithIndifferentAccess.new(decoded)
    rescue JWT::ExpiredSignature
      raise TokenExpiredError, 'Token has expired'
    rescue JWT::DecodeError
      raise TokenInvalidError, 'Invalid token'
    end

    def self.refresh_access_token(refresh_token)
      # Декодируем refresh токен
      decoded = decode(refresh_token)
      
      # Проверяем, что это refresh токен
      unless decoded[:token_type] == 'refresh'
        raise TokenInvalidError, 'Not a refresh token'
      end
      
      # Создаем новый access токен с тем же user_id
      encode_access_token(user_id: decoded[:user_id])
    end
  end
end 