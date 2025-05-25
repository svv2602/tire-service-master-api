class ApplicationController < ActionController::API
  include ActionController::MimeResponds
  include Pundit::Authorization
  include RequestLogging
  
  # Обработка ошибок
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
  rescue_from Pundit::NotAuthorizedError, with: :forbidden
  
  # Аутентификация и авторизация
  before_action :authenticate_request
  attr_reader :current_user
  
  protected
  
  def authenticate_request
    @current_user = AuthorizeApiRequest.new(request.headers).call
    render json: { error: 'Unauthorized' }, status: :unauthorized unless @current_user
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
end
