require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "sprockets/railtie"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module TireServiceMasterApi
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Kyiv"
    config.active_record.default_timezone = :local
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session_store, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true
    
    # Добавляем поддержку куки для API приложения
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore, 
                         key: '_tire_service_session',
                         domain: :all,  # Разрешаем cookies для всех поддоменов
                         secure: Rails.env.production?,  # Secure только в production
                         same_site: :lax  # Более гибкие настройки для cross-origin запросов
    
    # Добавляем автозагрузку папки lib
    config.autoload_paths << Rails.root.join('lib')
    
        # Добавляем автозагрузку папки middleware
    config.autoload_paths << Rails.root.join('app/middleware')
    
    # Требуем middleware файлы явно
    require_relative '../app/middleware/partner_data_filter_middleware'
    require_relative '../app/middleware/operator_data_filter_middleware'
    require_relative '../app/middleware/audit_context_middleware'

    # Добавляем middleware для автоматической фильтрации данных
    config.middleware.use PartnerDataFilterMiddleware
    config.middleware.use OperatorDataFilterMiddleware

    # Добавляем middleware для контекста аудита (должен быть одним из первых)
    config.middleware.insert_before ActionDispatch::RemoteIp, AuditContextMiddleware
    
    # Настройка I18n
    config.i18n.available_locales = %w[uk ru]
    config.i18n.default_locale = :uk
    config.i18n.fallbacks = true
    
    # Настройка аудита
    config.audit_async_default = Rails.env.production?

    # <== ВАЖНО Добавил строку
    config.active_storage.routes_prefix = '/api/rails/active_storage'

    # Security headers
    config.action_dispatch.default_headers = {
      'X-Frame-Options' => 'DENY',
      'X-Content-Type-Options' => 'nosniff',
      'X-XSS-Protection' => '1; mode=block',
      'X-Download-Options' => 'noopen',
      'X-Permitted-Cross-Domain-Policies' => 'none',
      'Referrer-Policy' => 'strict-origin-when-cross-origin',
      'Permissions-Policy' => 'geolocation=(), microphone=(), camera=()'
    }
  end
end
