module Auth
  class JsonWebToken
    # Секрет для подписи JWT токенов
    SECRET_KEY = Rails.application.credentials.secret_key_base
    
    # Токен действителен 24 часа по умолчанию
    def self.encode(payload, exp = 24.hours.from_now)
      payload[:exp] = exp.to_i
      JWT.encode(payload, SECRET_KEY)
    end
    
    def self.decode(token)
      decoded = JWT.decode(token, SECRET_KEY)[0]
      HashWithIndifferentAccess.new decoded
    rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::VerificationError
      nil
    end
  end
end
