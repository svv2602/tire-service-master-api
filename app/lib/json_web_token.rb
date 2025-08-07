class JsonWebToken
  # Получение секретного ключа из переменной окружения или credentials
  def self.secret_key
    ENV['SECRET_KEY_BASE'] || Rails.application.credentials.secret_key_base
  end

  def self.encode(payload)
    JWT.encode(
      payload.merge(exp: 24.hours.from_now.to_i),
      secret_key,
      'HS256'
    )
  end

  def self.decode(token)
    JWT.decode(
      token,
      secret_key,
      true,
      algorithm: 'HS256'
    ).first
  rescue JWT::DecodeError
    nil
  end
end 