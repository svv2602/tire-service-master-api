
module AuthHelper
  def auth_token_for_user(user)
    Auth::JsonWebToken.encode(user_id: user.id)
  end
  
  def auth_headers_for_user(user)
    token = auth_token_for_user(user)
    { 'Authorization' => "Bearer #{token}" }
  end
end

RSpec.configure do |config|
  config.include AuthHelper, type: :request
end
