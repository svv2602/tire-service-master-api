module RequestLogging
  extend ActiveSupport::Concern

  included do
    before_action :log_request_start
    after_action :log_request_end
  end

  private

  def log_request_start
    Thread.current[:request_start_time] = Time.now
    
    # Store request context for loggers
    Thread.current[:request_context] = {
      request_id: request.request_id,
      remote_ip: request.remote_ip,
      user_agent: request.user_agent,
      path: request.fullpath,
      method: request.method
    }

    # Add user context if authenticated
    if defined?(current_user) && current_user
      Thread.current[:request_context][:user_id] = current_user.id
      
      # Set user context for Sentry
      if defined?(Sentry)
        Sentry.set_user(id: current_user.id, email: current_user.email)
      end
    end

    # Log request start
    Rails.logger.info({
      event: 'request_started',
      path: request.fullpath,
      method: request.method
    })
  end

  def log_request_end
    start_time = Thread.current[:request_start_time]
    duration = start_time ? ((Time.now - start_time) * 1000).round(2) : nil
    
    # Log request end
    Rails.logger.info({
      event: 'request_completed',
      path: request.fullpath,
      method: request.method,
      status: response.status,
      duration_ms: duration,
      content_type: response.content_type
    })
    
    # Clear thread local variables to prevent memory leaks
    Thread.current[:request_start_time] = nil
    Thread.current[:request_context] = nil
    
    # Clear Sentry context
    Sentry.set_user(nil) if defined?(Sentry)
  end
end
