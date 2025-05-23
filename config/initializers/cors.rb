# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Allow specific origins for better security
    origins 'localhost:3000', '127.0.0.1:3000',
            'localhost:5173', '127.0.0.1:5173',
            'localhost:8080', '127.0.0.1:8080',
            'localhost:3008', '127.0.0.1:3008',
            '192.168.9.109:3008'

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: false
  end
end
