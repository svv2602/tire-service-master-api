require_relative '../../app/middleware/locale_middleware'

Rails.application.config.middleware.use LocaleMiddleware 