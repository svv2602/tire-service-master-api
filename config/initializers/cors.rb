# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

# Define allowed origins based on environment
def cors_allowed_origins
  if Rails.env.production?
    # Production: use ENV variable or fallback to specific domains
    env_origins = ENV['ALLOWED_ORIGINS']&.split(',')&.map(&:strip)
    env_origins.presence || [
      'https://service-station.tot.biz.ua',
      'https://service-station.tot.biz.ua:3008'
    ]
  else
    # Development/Test: allow localhost variants
    [
      'localhost:3000', '127.0.0.1:3000',
      'localhost:5173', '127.0.0.1:5173',
      'localhost:8080', '127.0.0.1:8080',
      'localhost:3008', '127.0.0.1:3008',
      'localhost:8000', '127.0.0.1:8000',
      '192.168.9.109:3008',
      '192.168.3.145:3008',
      # Non-production domains
      'http://service-station.tot.biz.ua:3008',
      'https://service-station.tot.biz.ua:3008',
      'http://service-station.tot.biz.ua',
      'https://service-station.tot.biz.ua',
      # Docker internal network
      /http:\/\/web:\d+/,
      /http:\/\/api:\d+/
    ]
  end
end

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*cors_allowed_origins)

    # Allow null origin for local file testing (development only)
    if Rails.env.development?
      origins(*cors_allowed_origins, ->(source, _env) { source.nil? })
    end

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true,
      max_age: 600,  # Cache preflight requests for 10 minutes
      expose: ['X-Request-Id', 'X-Runtime']  # Expose useful headers to frontend
  end
end
