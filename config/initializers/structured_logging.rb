# frozen_string_literal: true

# Structured JSON logging for production
# Enables better log parsing and analysis

if Rails.env.production?
  # Use JSON formatter for logs
  Rails.application.configure do
    # Use tagged logging with JSON format
    config.log_formatter = proc do |severity, timestamp, _progname, msg|
      log_entry = {
        timestamp: timestamp.iso8601,
        severity: severity,
        message: msg.is_a?(String) ? msg : msg.inspect,
        environment: Rails.env,
        pid: Process.pid
      }

      # Add request_id if available from Current attributes
      if defined?(Current) && Current.respond_to?(:request_id)
        log_entry[:request_id] = Current.request_id if Current.request_id.present?
      end

      "#{log_entry.to_json}\n"
    end
  end
end

# Custom log subscriber for controller actions
class StructuredLogSubscriber < ActiveSupport::LogSubscriber
  def process_action(event)
    return unless Rails.env.production?

    payload = event.payload
    status = payload[:status]

    log_data = {
      type: 'request',
      method: payload[:method],
      path: payload[:path],
      controller: payload[:controller],
      action: payload[:action],
      status: status,
      duration_ms: event.duration.round(2),
      view_time_ms: (payload[:view_runtime] || 0).round(2),
      db_time_ms: (payload[:db_runtime] || 0).round(2),
      format: payload[:format]
    }

    # Add request_id if available
    if payload[:headers].present?
      request_id = payload[:headers]['X-Request-Id']
      log_data[:request_id] = request_id if request_id.present?
    end

    # Log as info for success, warn for 4xx, error for 5xx
    severity = case status
               when 200..399 then :info
               when 400..499 then :warn
               else :error
               end

    Rails.logger.send(severity, log_data.to_json)
  end

  def redirect_to(event)
    return unless Rails.env.production?

    Rails.logger.info({
      type: 'redirect',
      location: event.payload[:location],
      status: event.payload[:status]
    }.to_json)
  end
end

# Attach the subscriber in production
if Rails.env.production?
  StructuredLogSubscriber.attach_to :action_controller
end

# Middleware to add request_id to logs
class RequestIdMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request_id = env['action_dispatch.request_id'] || SecureRandom.uuid

    # Set Current.request_id if Current class exists
    if defined?(Current) && Current.respond_to?(:request_id=)
      Current.request_id = request_id
    end

    # Tag logs with request_id
    Rails.logger.tagged(request_id) do
      @app.call(env)
    end
  ensure
    Current.request_id = nil if defined?(Current) && Current.respond_to?(:request_id=)
  end
end

# Insert middleware in the stack
Rails.application.config.middleware.insert_after(
  ActionDispatch::RequestId,
  RequestIdMiddleware
)
