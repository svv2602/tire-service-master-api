module Auth
  class TokenExpiredError < StandardError; end
  class TokenInvalidError < StandardError; end
  class TokenRevokedError < StandardError; end

  class JsonWebToken
    def self.encode(payload)
      payload = payload.dup
      payload[:exp] = 24.hours.from_now.to_i
      JWT.encode(payload, Rails.application.credentials.secret_key_base, 'HS256')
    end

    def self.decode(token)
      begin
        decoded = JWT.decode(
          token,
          Rails.application.credentials.secret_key_base,
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

    def self.refresh_access_token(refresh_token)
      decoded = decode(refresh_token)
      raise TokenInvalidError unless decoded[:token_type] == 'refresh'
      
      # Создаем новый access токен
      encode(user_id: decoded[:user_id], token_type: 'access')
    end
  end
end 