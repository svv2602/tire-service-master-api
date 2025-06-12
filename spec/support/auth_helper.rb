module AuthHelper
  def auth_token_for_user(user)
    Auth::JsonWebToken.encode_access_token(user_id: user.id)
  end
  
  def auth_headers_for_user(user)
    token = auth_token_for_user(user)
    { 'Authorization' => "Bearer #{token}" }
  end

  def generate_token(user)
    Auth::JsonWebToken.encode_access_token(user_id: user.id)
  end

  # Генерирует JWT токен для пользователя
  def generate_jwt_token(user)
    Auth::JsonWebToken.encode_access_token(user_id: user.id)
  end
end

RSpec.configure do |config|
  config.include AuthHelper, type: :request
end
