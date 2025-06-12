module JwtHelper
  def generate_jwt_token(user)
    Auth::JsonWebToken.encode_access_token(user_id: user.id)
  end
end

RSpec.configure do |config|
  config.include JwtHelper
end 