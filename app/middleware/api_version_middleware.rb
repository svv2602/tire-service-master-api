# frozen_string_literal: true

# Middleware that handles API-Version header for forward compatibility.
# - Reads the API-Version request header from the client
# - Sets the API-Version response header (defaults to "1" when not specified)
# - Stores the version in request env for controllers to access
#
# This allows gradual API evolution — mobile clients can pin to a version
# and the server can serve different responses based on requested version.
#
# Example:
#   Request:  API-Version: 1
#   Response: API-Version: 1
#
#   Request:  (no header)
#   Response: API-Version: 1
class ApiVersionMiddleware
  CURRENT_VERSION = '1'
  SUPPORTED_VERSIONS = %w[1].freeze
  HEADER_NAME = 'API-Version'
  ENV_KEY = 'api.version'

  def initialize(app)
    @app = app
  end

  def call(env)
    # Read requested version from header (HTTP headers are uppercased and prefixed)
    requested_version = env['HTTP_API_VERSION'] || CURRENT_VERSION

    # Store in env for controller access
    env[ENV_KEY] = if SUPPORTED_VERSIONS.include?(requested_version)
      requested_version
    else
      CURRENT_VERSION
    end

    status, headers, response = @app.call(env)

    # Always set API-Version in response headers
    headers[HEADER_NAME] = env[ENV_KEY]

    [status, headers, response]
  end
end
