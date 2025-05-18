Rails.application.config.after_initialize do
  if Rails.env.production? || Rails.env.staging?
    # Configure structured logging
    Rails.logger.formatter = LogFormatter.new

    # Configure Sentry for error tracking
    Sentry.init do |config|
      config.dsn = ENV['SENTRY_DSN']
      config.breadcrumbs_logger = [:active_support_logger, :http_logger]
      config.traces_sample_rate = 0.2
      config.send_default_pii = false
      config.environment = Rails.env
      config.release = ENV['GIT_COMMIT'] || 'development'
      
      # Exclude certain errors
      config.excluded_exceptions += [
        'ActionController::RoutingError',
        'ActiveRecord::RecordNotFound'
      ]
    end

    # Capture SQL queries in transactions with slow query detection
    ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      
      # Log slow queries (over 500ms)
      if event.duration > 500
        Rails.logger.warn({
          event: 'slow_query',
          duration_ms: event.duration.round(2),
          sql: event.payload[:sql].gsub(/\s+/, ' ').strip,
          name: event.payload[:name]
        })
      end
    end

    # Track controller actions
    ActiveSupport::Notifications.subscribe('process_action.action_controller') do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      payload = event.payload
      
      params = payload[:params].except(*ActionController::LogSubscriber::INTERNAL_PARAMS)
      
      # Log controller actions
      Rails.logger.info({
        event: 'controller_action',
        controller: payload[:controller],
        action: payload[:action],
        format: payload[:format],
        method: payload[:method],
        path: payload[:path],
        status: payload[:status],
        duration_ms: event.duration.round(2),
        db_duration_ms: payload[:db_runtime]&.round(2),
        view_duration_ms: payload[:view_runtime]&.round(2)
      })
    end
  end
end
