class LogFormatter < ::Logger::Formatter
  def call(severity, time, program_name, message)
    timestamp = time.strftime('%Y-%m-%dT%H:%M:%S.%3NZ')
    payload = {
      timestamp: timestamp,
      level: severity,
      pid: Process.pid,
      thread_id: Thread.current.object_id,
      service: Rails.application.class.module_parent_name
    }

    # Add context for exceptions
    if message.is_a?(Exception)
      exception = message
      payload[:error] = {
        class: exception.class.name,
        message: exception.message,
        backtrace: (exception.backtrace || []).take(20)
      }
      payload[:message] = exception.message
    elsif message.is_a?(Hash)
      # Handle hash messages for structured logging
      payload.merge!(message)
    else
      payload[:message] = message.to_s
    end

    # Add request context if available
    if Thread.current[:request_context].present?
      payload.merge!(Thread.current[:request_context])
    end

    "#{JSON.generate(payload)}\n"
  end
end
