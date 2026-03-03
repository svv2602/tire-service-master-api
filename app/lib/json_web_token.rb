# frozen_string_literal: true

# DEPRECATED: Use Auth::JsonWebToken instead.
# This class delegates to Auth::JsonWebToken for backward compatibility.
# The old implementation lacked token_type checks and blacklist validation.
class JsonWebToken
  def self.secret_key
    Auth::JsonWebToken.secret_key
  end

  def self.encode(payload)
    ActiveSupport::Deprecation.warn(
      'JsonWebToken.encode is deprecated. Use Auth::JsonWebToken.encode_access_token instead.'
    )
    Auth::JsonWebToken.encode_access_token(payload)
  end

  def self.decode(token)
    ActiveSupport::Deprecation.warn(
      'JsonWebToken.decode is deprecated. Use Auth::JsonWebToken.decode_access_token instead.'
    )
    Auth::JsonWebToken.decode(token)
  rescue Auth::TokenExpiredError, Auth::TokenInvalidError, Auth::TokenRevokedError
    nil
  end
end
