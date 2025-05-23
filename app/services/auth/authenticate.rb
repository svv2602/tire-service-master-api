module Auth
  class Authenticate
    attr_reader :email, :password, :ip_address, :user_agent
    
    def initialize(email, password, ip_address: nil, user_agent: nil)
      @email = email
      @password = password
      @ip_address = ip_address
      @user_agent = user_agent
    end
    
    def call
      if user && user.is_active && user.authenticate(password)
        log_successful_login
        generate_tokens
      else
        nil
      end
    end
    
    private
    
    def user
      @user ||= User.find_by(email: email)
    end
    
    def log_successful_login
      user.update_last_login!
      SystemLog.log_login(user, ip_address, user_agent)
    end
    
    def generate_tokens
      {
        access_token: JsonWebToken.encode_access_token(user_id: user.id),
        refresh_token: JsonWebToken.encode_refresh_token(user_id: user.id),
        token_type: 'Bearer',
        expires_in: JsonWebToken::ACCESS_TOKEN_EXPIRY.to_i
      }
    end
  end
end
