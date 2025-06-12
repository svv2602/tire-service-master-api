module Auth
  class JsonWebToken
    SECRET_KEY = Rails.application.credentials.secret_key_base

    def self.encode_access_token(payload)
      payload[:exp] = 24.hours.from_now.to_i
      payload[:token_type] = 'access'
      JWT.encode(payload, SECRET_KEY)
    end

    def self.decode(token)
      JWT.decode(token, SECRET_KEY)[0]
    rescue JWT::DecodeError
      nil
    end
  end
end 