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
    @user ||= User.find(decoded_token[:user_id]) if decoded_token
  rescue ActiveRecord::RecordNotFound
    nil
  end
  
  def decoded_token
    @decoded_token ||= Auth::JsonWebToken.decode(http_auth_header)
  end
  
  def http_auth_header
    if headers['Authorization'].present?
      return headers['Authorization'].split(' ').last
    end
    nil
  end
end
