class JsonWebToken
  def self.encode(payload)
    JWT.encode(
      payload.merge(exp: 24.hours.from_now.to_i),
      Rails.application.credentials.secret_key_base,
      'HS256'
    )
  end

  def self.decode(token)
    JWT.decode(
      token,
      Rails.application.credentials.secret_key_base,
      true,
      algorithm: 'HS256'
    ).first
  rescue JWT::DecodeError
    nil
  end
end 