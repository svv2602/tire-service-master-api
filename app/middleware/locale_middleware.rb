class LocaleMiddleware
  SUPPORTED_LOCALES = %w[uk ru].freeze
  DEFAULT_LOCALE = 'uk'.freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    
    # Определяем язык в следующем порядке:
    # 1. Из параметра запроса (?locale=uk)
    # 2. Из заголовка X-Locale
    # 3. Из заголовка Accept-Language
    # 4. Из настроек пользователя (если авторизован)
    # 5. Используем язык по умолчанию (украинский)
    I18n.locale = determine_locale(request)
    
    @app.call(env)
  end

  private

  def determine_locale(request)
    locale = locale_from_params(request) ||
             locale_from_header(request) ||
             locale_from_accept_language(request) ||
             locale_from_user(request) ||
             DEFAULT_LOCALE

    # Проверяем, что локаль поддерживается
    SUPPORTED_LOCALES.include?(locale.to_s) ? locale : DEFAULT_LOCALE
  end

  def locale_from_params(request)
    locale = request.params['locale']
    return nil unless locale
    locale.to_s.downcase
  end

  def locale_from_header(request)
    locale = request.get_header('HTTP_X_LOCALE')
    return nil unless locale
    locale.to_s.downcase
  end

  def locale_from_accept_language(request)
    accept_lang = request.get_header('HTTP_ACCEPT_LANGUAGE')
    return nil unless accept_lang

    # Парсим заголовок Accept-Language и находим первый поддерживаемый язык
    accepted_languages = accept_lang.split(',').map { |l| l.split(';').first.strip.downcase }
    accepted_languages.find { |l| SUPPORTED_LOCALES.include?(l) }
  end

  def locale_from_user(request)
    # Получаем текущего пользователя из JWT токена
    auth_header = request.get_header('HTTP_AUTHORIZATION')
    return nil unless auth_header

    begin
      token = auth_header.split(' ').last
      decoded_token = JWT.decode(token, Rails.application.credentials.secret_key_base, true, algorithm: 'HS256')
      user_id = decoded_token.first['user_id']
      
      # Получаем настройки языка пользователя
      user = User.find_by(id: user_id)
      user&.preferred_locale
    rescue JWT::DecodeError
      nil
    end
  end
end 