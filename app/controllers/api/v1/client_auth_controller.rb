# Контроллер для аутентификации клиентов
class Api::V1::ClientAuthController < ApplicationController
  # Не требуем авторизации для регистрации и входа
  skip_before_action :authenticate_request, only: [:register, :login]

  # POST /api/v1/clients/register
  # Регистрация нового клиента
  def register
    begin
      # Находим роль клиента
      client_role = UserRole.find_by(name: 'client')
      unless client_role
        render json: { error: 'Роль клиента не настроена в системе' }, status: :internal_server_error
        return
      end

      # Создаем пользователя с ролью клиента
      user = User.new(user_params.merge(role: client_role))
      
      if user.save
        # Пользователь автоматически создаст связанный Client через коллбэк
        
        # Генерируем JWT токен
        token = Auth::JsonWebToken.encode_access_token(user_id: user.id)
        
        render json: {
          message: 'Account created successfully',
          auth_token: token
        }, status: :created
      else
        render json: { 
          error: 'Ошибка регистрации', 
          details: user.errors.full_messages 
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error "Ошибка регистрации клиента: #{e.message}"
      render json: { error: 'Внутренняя ошибка сервера' }, status: :internal_server_error
    end
  end

  # POST /api/v1/clients/login
  # Вход клиента в систему
  def login
    begin
      # Ищем пользователя по email или телефону
      user = find_user_by_credentials(login_params[:login])
      
      unless user
        render json: { error: 'Пользователь не найден' }, status: :not_found
        return
      end

      # Проверяем что это клиент
      unless user.client?
        render json: { error: 'Пользователь не является клиентом' }, status: :forbidden
        return
      end

      # Проверяем пароль
      unless user.authenticate(login_params[:password])
        render json: { error: 'Неверный пароль' }, status: :unauthorized
        return
      end

      # Проверяем что аккаунт активен
      unless user.is_active?
        render json: { error: 'Аккаунт заблокирован' }, status: :forbidden
        return
      end

      # Обновляем время последнего входа
      user.update_last_login!

      # Генерируем JWT токен
      token = Auth::JsonWebToken.encode_access_token(user_id: user.id)

      render json: {
        message: 'Вход выполнен успешно',
        auth_token: token
      }, status: :ok
    rescue StandardError => e
      Rails.logger.error "Ошибка входа клиента: #{e.message}"
      render json: { error: 'Внутренняя ошибка сервера' }, status: :internal_server_error
    end
  end

  # POST /api/v1/clients/logout
  # Выход из системы (для полноты API, на стороне клиента просто удаляется токен)
  def logout
    # В JWT нет server-side логаута, токен просто перестают использовать на клиенте
    render json: { message: 'Выход выполнен успешно' }, status: :ok
  end

  # GET /api/v1/clients/me
  # Получение информации о текущем клиенте
  def me
    unless current_user&.client?
      render json: { error: 'Доступ запрещен' }, status: :forbidden
      return
    end

    render json: {
      user: {
        id: current_user.id,
        email: current_user.email,
        first_name: current_user.first_name,
        last_name: current_user.last_name,
        phone: current_user.phone,
        email_verified: current_user.email_verified,
        phone_verified: current_user.phone_verified,
        role: current_user.role.name,
        is_active: current_user.is_active?
      },
      client: {
        id: current_user.client.id,
        preferred_notification_method: current_user.client.preferred_notification_method,
        total_bookings: current_user.client.total_bookings,
        completed_bookings: current_user.client.completed_bookings,
        average_rating_given: current_user.client.average_rating_given
      }
    }, status: :ok
  end

  private

  def user_params
    params.require(:client).permit(:first_name, :last_name, :email, :phone, :password, :password_confirmation)
  end

  def login_params
    params.require(:auth).permit(:login, :password)
  end

  def find_user_by_credentials(login)
    # Ищем по email или телефону
    if login.include?('@')
      User.find_by(email: login.downcase)
    else
      # Нормализуем телефон для поиска
      normalized_phone = login.gsub(/[^\d+]/, '')
      User.find_by(phone: normalized_phone)
    end
  end
end 