class ApplicationController < ActionController::API
  include ActionController::MimeResponds
  include ActionController::Cookies
  include Pundit::Authorization
  include RequestLogging
  include ActionController::HttpAuthentication::Token::ControllerMethods
  
  # Обработка ошибок
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
  rescue_from Pundit::NotAuthorizedError, with: :forbidden
  rescue_from ActionDispatch::Http::Parameters::ParseError, with: :bad_request
  
  # Аутентификация и авторизация
  before_action :authenticate_request
  attr_reader :current_user
  
  protected
  
  def authenticate_request
    # Сначала пробуем получить токен из cookies (приоритет)
    access_token = cookies.encrypted[:access_token]
    Rails.logger.info("Auth: access_token from cookies: #{access_token.present? ? 'present' : 'nil'}")
    
    # Если нет в cookies, пробуем из заголовка Authorization (для обратной совместимости)
    if access_token.nil?
      header = request.headers['Authorization']
      access_token = header.split(' ').last if header
      Rails.logger.info("Auth: access_token from header: #{access_token.present? ? 'present' : 'nil'}")
    end
    
    if access_token.nil?
      Rails.logger.info("Auth: No token found, returning unauthorized")
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
      Rails.logger.info("Auth: Successfully authenticated user: #{@current_user.email} (ID: #{@current_user.id})")
      
      # Проверяем, что пользователь активен
      unless @current_user.is_active
        Rails.logger.info("Auth: User account is inactive")
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

  # Попытка автоматического обновления токена
  def try_refresh_token
    refresh_token = cookies.encrypted[:refresh_token]
    return false if refresh_token.blank?

    begin
      new_access_token = Auth::JsonWebToken.refresh_access_token(refresh_token)
      
      # Устанавливаем новый access токен в cookie
      cookies.encrypted[:access_token] = {
        value: new_access_token,
        httponly: true,
        secure: Rails.env.production?,
        same_site: :lax,
        expires: 1.hour.from_now
      }
      
      Rails.logger.info("Token auto-refreshed successfully")
      return true
    rescue Auth::TokenExpiredError, Auth::TokenInvalidError, Auth::TokenRevokedError => e
      # Удаляем недействительные cookies
      cookies.delete(:access_token)
      cookies.delete(:refresh_token)
      Rails.logger.info("Failed to refresh token: #{e.message}")
      return false
    end
  end
  
  def current_ip
    request.remote_ip
  end
  
  def current_user_agent
    request.user_agent
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
  
  def json_request?
    request.format.json?
  end
end
