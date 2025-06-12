class ApplicationController < ActionController::API
  include ActionController::MimeResponds
  include Pundit::Authorization
  include RequestLogging
  include ActionController::HttpAuthentication::Token::ControllerMethods
  
  # Обработка ошибок
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
  rescue_from Pundit::NotAuthorizedError, with: :forbidden
  
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
      if decoded.nil? || !decoded['user_id']
        render json: { error: 'Неверный токен' }, status: :unauthorized
        return
      end
      
      @current_user = User.find(decoded['user_id'])
    rescue JWT::DecodeError => e
      render json: { error: 'Неверный токен' }, status: :unauthorized
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
  
  def json_request?
    request.format.json?
  end
end
