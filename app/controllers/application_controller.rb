class ApplicationController < ActionController::API
  include ActionController::MimeResponds
  include ActionController::Cookies
  include ActionController::RequestForgeryProtection
  include Pundit::Authorization
  include RequestLogging
  include ActionController::HttpAuthentication::Token::ControllerMethods

  # CSRF protection for cookie-based auth
  before_action :set_csrf_cookie
  
  # Обработка ошибок
  rescue_from StandardError, with: :internal_server_error if Rails.env.production?
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
  rescue_from Pundit::NotAuthorizedError, with: :forbidden
  rescue_from ActionDispatch::Http::Parameters::ParseError, with: :bad_request
  
  # Аутентификация и авторизация
  before_action :authenticate_request
  attr_reader :current_user
  
  protected
  
  def authenticate_request
    # Security: log only presence, never token values
    access_token = cookies[:access_token]
    Rails.logger.debug "Auth: cookie_token=#{access_token.present?}"

    # Если нет в cookies, пробуем из заголовка Authorization (для обратной совместимости)
    if access_token.nil?
      header = request.headers['Authorization']
      access_token = header.split(' ').last if header
      Rails.logger.debug "Auth: header_token=#{access_token.present?}"
    end

    if access_token.nil?
      Rails.logger.debug "Auth: no token found"
      render json: { error: 'Токен не предоставлен' }, status: :unauthorized
      return
    end

    begin
      decoded = Auth::JsonWebToken.decode(access_token)

      # Проверяем, что это access токен
      unless decoded[:token_type] == 'access'
        render json: { error: 'Неверный тип токена' }, status: :unauthorized
        return
      end

      @current_user = User.find(decoded[:user_id])
      Rails.logger.debug "Auth: authenticated user_id=#{@current_user.id}"

      # Проверяем, что пользователь активен
      unless @current_user.is_active
        Rails.logger.debug "Auth: user_id=#{@current_user.id} is inactive"
        render json: { error: 'Учетная запись отключена' }, status: :forbidden
        return
      end

    rescue Auth::TokenExpiredError => e
      # Пробуем обновить токен из refresh cookie
      if try_refresh_token
        retry
      else
        render json: { error: 'Токен истек', code: 'token_expired' }, status: :unauthorized
      end
    rescue Auth::TokenInvalidError => e
      render json: { error: 'Неверный токен', code: 'invalid_token' }, status: :unauthorized
    rescue ActiveRecord::RecordNotFound => e
      render json: { error: 'Пользователь не найден' }, status: :unauthorized
    end
  end

  # Строгая аутентификация (вызывает исключение при ошибке)
  def authenticate_request!
    authenticate_request
    if @current_user.nil?
      raise Pundit::NotAuthorizedError, "Требуется аутентификация"
    end
  end
  
  # Глобальная переменная для отслеживания попыток обновления токенов
  @@token_refresh_attempts = {}
  @@token_refresh_mutex = Mutex.new

  # Попытка автоматического обновления токена
  def try_refresh_token
    refresh_token = cookies[:refresh_token]
    return false if refresh_token.blank?

    # Создаем уникальный ключ для пользователя (используем refresh_token как идентификатор)
    user_key = Digest::SHA256.hexdigest(refresh_token)[0..16]
    
    # Защита от зацикливания - используем глобальную переменную класса с мьютексом
    @@token_refresh_mutex.synchronize do
      last_attempt = @@token_refresh_attempts[user_key]
      # Увеличиваем интервал защиты с 10 секунд до 2 минут для предотвращения зацикливания
      if last_attempt && Time.current - last_attempt < 2.minutes
        Rails.logger.debug "TokenRefresh: too frequent, skipping"
        return false
      end

      # Записываем время попытки
      @@token_refresh_attempts[user_key] = Time.current

      # Очищаем старые записи (старше 1 часа)
      @@token_refresh_attempts.delete_if { |k, v| Time.current - v > 1.hour }
    end

    begin
      new_access_token = Auth::JsonWebToken.refresh_access_token(refresh_token)
      
      # Устанавливаем новый access токен в cookie
      cookies[:access_token] = {
        value: new_access_token,
        httponly: true,
        secure: Rails.env.production?,
        same_site: :lax,
        expires: 1.hour.from_now,
        path: '/'
      }
      
      Rails.logger.debug "TokenRefresh: success"
      
      # 🔧 ИСПРАВЛЕНИЕ: НЕ сбрасываем счетчик попыток после успешного обновления
      # Это предотвращает зацикливание - токен будет обновлен только раз в 2 минуты
      # @@token_refresh_attempts.delete(user_key) - УБРАНО для предотвращения зацикливания
      
      return true
    rescue Auth::TokenExpiredError, Auth::TokenInvalidError, Auth::TokenRevokedError => e
      # Удаляем недействительные cookies
      cookies.delete(:access_token)
      cookies.delete(:refresh_token)
      
      # 🔧 ИСПРАВЛЕНИЕ: НЕ сбрасываем счетчик попыток при ошибке
      # Оставляем защиту активной для предотвращения повторных попыток
      # @@token_refresh_attempts.delete(user_key) - УБРАНО для предотвращения зацикливания
      
      Rails.logger.debug "TokenRefresh: failed"
      return false
    end
  end
  
  def current_ip
    request.remote_ip
  end
  
  def current_user_agent
    request.user_agent
  end
  
  # Проверка прав администратора
  def ensure_admin!
    unless current_user&.admin?
      render json: { error: 'Доступ запрещен' }, status: :forbidden
    end
  end
  
  private
  
  def not_found
    render json: { error: 'Resource not found' }, status: :not_found
  end
  
  def unprocessable_entity(exception)
    render json: { error: exception.message }, status: :unprocessable_entity
  end
  
  def unauthorized
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end
  
  def forbidden
    render json: { error: 'Forbidden' }, status: :forbidden
  end
  
  def bad_request
    render json: { error: 'Bad request - malformed parameters' }, status: :bad_request
  end

  def internal_server_error(exception)
    Rails.logger.error "Unhandled exception: #{exception.class} - #{exception.message}"
    Rails.logger.error exception.backtrace&.first(20)&.join("\n")
    render json: { error: 'Internal server error' }, status: :internal_server_error
  end
  
  def json_request?
    request.format.json?
  end

  # Set CSRF token in cookie for JavaScript to read
  def set_csrf_cookie
    cookies['XSRF-TOKEN'] = {
      value: form_authenticity_token,
      same_site: :lax,
      secure: Rails.env.production?,
      httponly: false,  # Must be readable by JavaScript
      path: '/'
    }
  end
end
