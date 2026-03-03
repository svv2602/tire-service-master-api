class AuditContextMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)

    # Set up audit context for the current request
    setup_audit_context(request)

    # Execute the request
    response = @app.call(env)

    # Clean up context after request completes
    cleanup_audit_context

    response
  rescue => e
    # Clean up context even on error
    cleanup_audit_context
    raise e
  end

  private

  def setup_audit_context(request)
    # Extract client IP address
    ip_address = extract_client_ip(request)

    # Extract User-Agent
    user_agent = request.user_agent

    # Generate unique request ID
    request_id = generate_request_id

    # Extract session ID if available
    session_id = extract_session_id(request)

    # Extract current user from token (if present)
    current_user = extract_current_user(request)

    # Store context in CurrentContext (thread-safe, auto-reset per request)
    CurrentContext.ip_address = ip_address
    CurrentContext.user_agent = user_agent
    CurrentContext.request_id = request_id
    CurrentContext.session_id = session_id
    CurrentContext.audit_user = current_user

    # Log request start for API endpoints
    log_request_start(request, current_user, ip_address, user_agent, request_id) if api_request?(request)
  end

  def cleanup_audit_context
    # Reset all audit-related attributes
    CurrentContext.reset
  end

  def extract_client_ip(request)
    # Get real client IP, accounting for proxies
    request.headers['HTTP_X_REAL_IP'] ||
      request.headers['HTTP_X_FORWARDED_FOR']&.split(',')&.first&.strip ||
      request.remote_ip
  end

  def extract_session_id(request)
    # Try to get session ID from cookies or headers
    request.session.id if request.session.respond_to?(:id)
  rescue
    nil
  end

  def extract_current_user(request)
    # Extract user from JWT token
    auth_header = request.headers['Authorization']
    return nil unless auth_header&.start_with?('Bearer ')

    token = auth_header.split(' ').last
    return nil unless token

    begin
      decoded_token = JWT.decode(
        token,
        Auth::JsonWebToken.secret_key,
        true,
        { algorithm: 'HS256' }
      )
      user_id = decoded_token[0]['user_id']
      User.find_by(id: user_id)
    rescue JWT::DecodeError, JWT::ExpiredSignature, ActiveRecord::RecordNotFound
      nil
    end
  end

  def generate_request_id
    # Generate unique request ID
    SecureRandom.uuid
  end

  def api_request?(request)
    # Check if this is an API request
    request.path.start_with?('/api/')
  end

  def log_request_start(request, user, ip_address, user_agent, request_id)
    # Log API request start for activity tracking
    return unless should_log_request?(request)

    AuditLogJob.perform_later(
      action: 'api_request',
      user_id: user&.id,
      additional_data: {
        method: request.method,
        path: request.path,
        query_params: sanitize_query_params(request.query_parameters),
        request_id: request_id,
        timestamp: Time.current
      },
      ip_address: ip_address,
      user_agent: user_agent
    )
  end

  def should_log_request?(request)
    # Determine whether to log this request
    # Skip non-critical requests to save storage
    excluded_paths = [
      '/api/v1/health',
      '/api/v1/ping',
      '/api/v1/status'
    ]

    # Don't log GET requests to non-critical endpoints
    return false if request.get? && excluded_paths.any? { |path| request.path.start_with?(path) }

    # Log all POST, PUT, PATCH, DELETE requests
    return true if %w[POST PUT PATCH DELETE].include?(request.method)

    # Log GET requests to critical endpoints
    critical_paths = [
      '/api/v1/users',
      '/api/v1/admin',
      '/api/v1/audit_logs'
    ]

    critical_paths.any? { |path| request.path.start_with?(path) }
  end

  def sanitize_query_params(params)
    # Remove sensitive data from request parameters
    sensitive_keys = %w[password password_confirmation token api_key secret]

    params.deep_dup.tap do |sanitized|
      sensitive_keys.each do |key|
        sanitized.delete(key)
        sanitized.each_value do |value|
          if value.is_a?(Hash)
            value.delete(key)
          end
        end
      end
    end
  end
end
