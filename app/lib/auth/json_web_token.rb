module Auth
  class TokenExpiredError < StandardError; end
  class TokenInvalidError < StandardError; end
  class TokenRevokedError < StandardError; end

  class JsonWebToken
    ACCESS_TOKEN_EXPIRY = 1.hour
    REFRESH_TOKEN_EXPIRY = 30.days

    # Получение секретного ключа из переменной окружения или credentials
    def self.secret_key
      ENV['SECRET_KEY_BASE'] || Rails.application.credentials.secret_key_base
    end

    # Configurable access token TTL (defaults to 1 hour)
    def self.access_token_ttl
      hours = ENV.fetch('JWT_ACCESS_TTL_HOURS', '1').to_i
      hours = 1 if hours <= 0
      hours.hours
    end

    # Configurable refresh token TTL (defaults to 30 days)
    def self.refresh_token_ttl
      days = ENV.fetch('JWT_REFRESH_TTL_DAYS', '30').to_i
      days = 30 if days <= 0
      days.days
    end

    def self.encode(payload)
      payload = payload.dup
      payload[:jti] = SecureRandom.uuid
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
        result = HashWithIndifferentAccess.new(decoded)

        # Check token blacklist (individual token revocation)
        raise TokenRevokedError, 'Token has been revoked' if TokenBlacklistService.revoked?(token)

        # Check user-level revocation (e.g. password change)
        if result[:user_id] && result[:iat]
          if TokenBlacklistService.user_tokens_revoked?(result[:user_id], result[:iat])
            raise TokenRevokedError, 'Token has been revoked due to credential change'
          end
        end

        result
      rescue JWT::ExpiredSignature
        raise TokenExpiredError
      rescue JWT::DecodeError
        raise TokenInvalidError
      end
    end

    # Создание access токена (короткий срок жизни)
    def self.encode_access_token(payload)
      payload = payload.dup
      payload[:jti] = SecureRandom.uuid
      payload[:token_type] = 'access'
      payload[:iat] = Time.current.to_i
      payload[:exp] = access_token_ttl.from_now.to_i
      JWT.encode(payload, secret_key, 'HS256')
    end

    # Создание refresh токена (длительный срок жизни)
    def self.encode_refresh_token(payload)
      payload = payload.dup
      payload[:jti] = SecureRandom.uuid
      payload[:token_type] = 'refresh'
      payload[:iat] = Time.current.to_i
      payload[:exp] = refresh_token_ttl.from_now.to_i
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