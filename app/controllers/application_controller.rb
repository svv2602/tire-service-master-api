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
    header = request.headers['Authorization']
    token = header.split(' ').last if header
    
    if token.nil?
      render json: { error: 'Токен не предоставлен' }, status: :unauthorized
      return
    end
    
    begin
      decoded = Auth::JsonWebToken.decode(token)
      
      # Проверяем, что это access токен
      unless decoded[:token_type] == 'access'
        render json: { error: 'Неверный тип токена' }, status: :unauthorized
        return
      end
      
      @current_user = User.find(decoded[:user_id])
      
      # Проверяем, что пользователь активен
      unless @current_user.is_active
        render json: { error: 'Учетная запись отключена' }, status: :forbidden
        return
      end
      
    rescue Auth::TokenExpiredError => e
      render json: { error: 'Токен истек', code: 'token_expired' }, status: :unauthorized
    rescue Auth::TokenInvalidError => e
      render json: { error: 'Неверный токен', code: 'invalid_token' }, status: :unauthorized
    rescue ActiveRecord::RecordNotFound => e
      render json: { error: 'Пользователь не найден' }, status: :unauthorized
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
