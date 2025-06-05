source "https://rubygems.org"

ruby "3.3.7"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.2"

# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", "~> 6.0"

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Redis adapter to run Action Cable in production
gem "redis", "~> 5.0"

# Use Active Model has_secure_password
gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# CSV support (removes Ruby 3.4 deprecation warning)
gem "csv"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS)
gem "rack-cors"

# Authentication
gem "jwt"
gem "dotenv-rails"

# Pagination
gem "pagy"

# API helpers
gem "active_model_serializers", "~> 0.10.13"
gem "pundit", "~> 2.3"

# Background processing & jobs
gem "sidekiq", "~> 7.1"

# Monitoring and debugging
gem "sentry-ruby"
gem "sentry-rails"

# State machines
gem "aasm"

# Validation
gem "dry-validation"

# API Documentation
gem "rswag-api"
gem "rswag-ui"
gem "rswag-specs"

# Testing
group :development, :test do
  # Debugging
  gem "debug", platforms: %i[ mri mingw x64_mingw ]
  gem "pry-rails"
  
  # Testing
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "shoulda-matchers"
  gem "database_cleaner-active_record"
end

group :development do
  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  gem "spring"
  
  # Code quality
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end

gem "base64", "~> 0.3.0"
