class AuthorizeApiRequest
  attr_reader :headers
  
  def initialize(headers = {})
    @headers = headers
  end
  
  def call
    user
  end
  
  private
  
  def user
    begin
      @user ||= User.find(decoded_token[:user_id]) if decoded_token
    rescue ActiveRecord::RecordNotFound
      nil
    rescue Auth::TokenExpiredError
      Rails.logger.error("Access token has expired")
      nil
    rescue Auth::TokenInvalidError => e
      Rails.logger.error("Invalid access token: #{e.message}")
      nil
    end
  end
  
  def decoded_token
    @decoded_token ||= begin
      token = http_auth_header
      return nil unless token
      
      decoded = Auth::JsonWebToken.decode(token)
      
      # Проверяем, что это access token
      if decoded && decoded[:token_type] != 'access'
        Rails.logger.error("Invalid token type: #{decoded[:token_type]}")
        raise Auth::TokenInvalidError, 'Invalid token type'
      end
      
      decoded
    end
  end
  
  def http_auth_header
    Rails.logger.info("Authorization header: #{headers['Authorization']}")
    if headers['Authorization'].present?
      token = headers['Authorization'].split(' ').last
      Rails.logger.info("Extracted token: #{token}")
      return token
    end
    nil
  end
end
