# frozen_string_literal: true

# ActionCable configuration for WebSocket connections
# Defines allowed origins for WebSocket connections based on environment

Rails.application.config.action_cable.mount_path = '/cable'

# Allowed request origins for WebSocket connections
# Must include same origins as CORS config
if Rails.env.production?
  origins = ENV['ALLOWED_ORIGINS']&.split(',')&.map(&:strip) || [
    'https://service-station.tot.biz.ua',
    'https://service-station.tot.biz.ua:3008'
  ]
  Rails.application.config.action_cable.allowed_request_origins = origins
else
  # Development: allow localhost and local network IPs
  Rails.application.config.action_cable.allowed_request_origins = [
    'http://localhost:3000', 'http://127.0.0.1:3000',
    'http://localhost:5173', 'http://127.0.0.1:5173',
    'http://localhost:8080', 'http://127.0.0.1:8080',
    'http://localhost:3008', 'http://127.0.0.1:3008',
    'http://localhost:8000', 'http://127.0.0.1:8000',
    'http://192.168.9.109:3008',
    'http://192.168.3.145:3008',
    'http://service-station.tot.biz.ua:3008',
    'https://service-station.tot.biz.ua:3008',
    'http://service-station.tot.biz.ua',
    'https://service-station.tot.biz.ua',
    # Allow any origin in development (for testing)
    %r{http://.*},
    %r{https://.*}
  ]

  # Disable origin checks in development for easier debugging
  Rails.application.config.action_cable.disable_request_forgery_protection = true
end

# URL for ActionCable server (if running separately)
# Rails.application.config.action_cable.url = ENV.fetch('ACTION_CABLE_URL', 'ws://localhost:8000/cable')

# Log WebSocket connections for debugging
Rails.application.config.action_cable.logger = ActiveSupport::TaggedLogging.new(
  Logger.new(Rails.root.join('log', 'action_cable.log'))
)
