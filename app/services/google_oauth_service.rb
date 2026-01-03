# frozen_string_literal: true

# Service for verifying Google OAuth tokens
# Uses Google's tokeninfo endpoint to validate ID tokens
class GoogleOAuthService
  GOOGLE_TOKEN_INFO_URL = 'https://oauth2.googleapis.com/tokeninfo'

  class TokenVerificationError < StandardError; end
  class InvalidTokenError < TokenVerificationError; end
  class ExpiredTokenError < TokenVerificationError; end
  class InvalidAudienceError < TokenVerificationError; end

  def initialize(id_token)
    @id_token = id_token
  end

  # Verifies the Google ID token and returns user info
  # @return [Hash] User info from Google
  # @raise [TokenVerificationError] If token is invalid
  def verify
    response = HTTParty.get(
      GOOGLE_TOKEN_INFO_URL,
      query: { id_token: @id_token },
      timeout: 10
    )

    unless response.success?
      error_message = response.parsed_response['error_description'] || 'Token verification failed'
      raise InvalidTokenError, error_message
    end

    token_info = response.parsed_response

    # Validate token hasn't expired
    if token_info['exp'].to_i < Time.now.to_i
      raise ExpiredTokenError, 'Token has expired'
    end

    # Validate audience (client ID) if configured
    validate_audience(token_info['aud']) if google_client_id.present?

    # Return normalized user info
    {
      provider_user_id: token_info['sub'],
      email: token_info['email'],
      email_verified: token_info['email_verified'] == 'true',
      first_name: token_info['given_name'],
      last_name: token_info['family_name'],
      picture: token_info['picture'],
      locale: token_info['locale']
    }
  rescue HTTParty::Error, Timeout::Error => e
    Rails.logger.error "Google OAuth verification HTTP error: #{e.message}"
    raise TokenVerificationError, "Failed to verify token: #{e.message}"
  end

  # Convenience class method
  def self.verify(id_token)
    new(id_token).verify
  end

  private

  def validate_audience(token_audience)
    unless token_audience == google_client_id
      Rails.logger.warn "Google OAuth: Invalid audience. Expected: #{google_client_id}, Got: #{token_audience}"
      raise InvalidAudienceError, 'Invalid token audience'
    end
  end

  def google_client_id
    ENV['GOOGLE_CLIENT_ID']
  end
end
