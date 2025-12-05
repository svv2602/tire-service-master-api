module AuthHelper
  def auth_token_for_user(user)
    Auth::JsonWebToken.encode_access_token(user_id: user.id)
  end

  def auth_headers_for_user(user)
    token = auth_token_for_user(user)
    { 'Authorization' => "Bearer #{token}" }
  end

  # Alias for convenience
  def auth_headers(user)
    auth_headers_for_user(user)
  end

  def generate_token(user)
    Auth::JsonWebToken.encode_access_token(user_id: user.id)
  end

  # Генерирует JWT токен для пользователя
  def generate_jwt_token(user)
    Auth::JsonWebToken.encode_access_token(user_id: user.id)
  end

  # Parse JSON response body
  def json_response
    JSON.parse(response.body, symbolize_names: true)
  rescue JSON::ParserError
    {}
  end
end

RSpec.configure do |config|
  config.include AuthHelper, type: :request
end
