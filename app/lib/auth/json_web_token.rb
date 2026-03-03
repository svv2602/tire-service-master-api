module Auth
  class TokenExpiredError < StandardError; end
  class TokenInvalidError < StandardError; end
  class TokenRevokedError < StandardError; end

  class JsonWebToken
    # Получение секретного ключа из переменной окружения или credentials
    def self.secret_key
      ENV['SECRET_KEY_BASE'] || Rails.application.credentials.secret_key_base
    end

    def self.encode(payload)
      payload = payload.dup
      payload[:exp] = 24.hours.from_now.to_i
      JWT.encode(payload, secret_key, 'HS256')
    end

    def self.decode(token)
      begin
        decoded = JWT.decode(
          token,
          secret_key,
          true,
          algorithm: 'HS256'
        ).first
        HashWithIndifferentAccess.new(decoded)
      rescue JWT::ExpiredSignature
        raise TokenExpiredError
      rescue JWT::DecodeError
        raise TokenInvalidError
      end
    end

    # Создание access токена (короткий срок жизни)
    def self.encode_access_token(payload)
      payload = payload.dup
      payload[:token_type] = 'access'
      payload[:exp] = 1.hour.from_now.to_i
      JWT.encode(payload, secret_key, 'HS256')
    end

    # Создание refresh токена (длительный срок жизни)
    def self.encode_refresh_token(payload)
      payload = payload.dup
      payload[:token_type] = 'refresh'
      payload[:exp] = 30.days.from_now.to_i
      JWT.encode(payload, secret_key, 'HS256')
    end

    # Декодирование access токена
    def self.decode_access_token(token)
      decoded = decode(token)
      raise TokenInvalidError unless decoded[:token_type] == 'access'
      decoded
    end

    # Декодирование refresh токена
    def self.decode_refresh_token(token)
      decoded = decode(token)
      raise TokenInvalidError unless decoded[:token_type] == 'refresh'
      decoded
    end

    def self.refresh_access_token(refresh_token)
      Rails.logger.info "Attempting to refresh token..."
      decoded = decode_refresh_token(refresh_token)
      Rails.logger.info "✅ Successfully decoded refresh token for user: #{decoded[:user_id]}"
      
      # Создаем новый access токен
      new_token = encode_access_token(user_id: decoded[:user_id])
      Rails.logger.info "✅ Generated new access token"
      new_token
    end
  end
end 