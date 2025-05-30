module RequestSpecHelper
  # Parse JSON response to ruby hash
  def json
    JSON.parse(response.body)
  rescue JSON::ParserError
    {}
  end

  # Parse response headers
  def auth_token
    response.headers['Authorization']
  end

  # Helper method to authenticate users in tests
  def authenticate_user(user)
    token = generate_token(user.id)
    { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
  end
  
  # Helper to prepare JSON data for requests
  def json_request(data)
    data.to_json
  end

  def valid_headers(user = nil)
    return {} unless user

    token = generate_token(user.id)
    {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json'
    }
  end

  private

  # Generate JWT token for test users
  def generate_token(user_id)
    Auth::JsonWebToken.encode_access_token(user_id: user_id)
  end
end
