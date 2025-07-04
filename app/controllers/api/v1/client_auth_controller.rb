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
        # Создаем клиента вручную, если он не был создан автоматически
        client = user.client || Client.create!(user: user, preferred_notification_method: 'email')
        
        # Генерируем JWT токены
        access_token = Auth::JsonWebToken.encode_access_token(user_id: user.id)
        refresh_token = Auth::JsonWebToken.encode_refresh_token(user_id: user.id)
        
        # Устанавливаем refresh токен в HttpOnly куки
        cookies.encrypted[:refresh_token] = {
          value: refresh_token,
          httponly: true,
          secure: Rails.env.production?,
          same_site: :strict,
          expires: 30.days.from_now
        }
        
        # Возвращаем ответ в формате, соответствующем тестам
        render json: {
          message: 'Регистрация прошла успешно',
          user: user.as_json(only: [:id, :email, :first_name, :last_name, :phone]),
          client: client.as_json(only: [:id, :preferred_notification_method]),
          tokens: {
            access: access_token
            # Refresh токен теперь в куки
          }
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
      # Ищем пользователя по email
      user = User.find_by(email: login_params[:email])
      
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

      # Генерируем JWT токены
      access_token = Auth::JsonWebToken.encode_access_token(user_id: user.id)
      refresh_token = Auth::JsonWebToken.encode_refresh_token(user_id: user.id)
      
      # Устанавливаем refresh токен в HttpOnly куки
      cookies.encrypted[:refresh_token] = {
        value: refresh_token,
        httponly: true,
        secure: Rails.env.production?,
        same_site: :lax,
        expires: 30.days.from_now,
        path: '/'
      }

      # Возвращаем ответ в формате, соответствующем тестам
      render json: {
        user: {
          id: user.id,
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name,
          is_active: user.is_active?,
          role: user.role.name
        },
        tokens: {
          access: access_token
          # Refresh токен теперь в куки
        },
        message: 'Вход выполнен успешно'
      }, status: :ok
    rescue StandardError => e
      Rails.logger.error "Ошибка входа клиента: #{e.message}"
      render json: { error: 'Внутренняя ошибка сервера' }, status: :internal_server_error
    end
  end

  # POST /api/v1/clients/logout
  # Выход из системы
  def logout
    # Удаляем куки при выходе
    cookies.delete(:refresh_token)
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
    params.require(:user).permit(:first_name, :last_name, :email, :phone, :password, :password_confirmation)
  end

  def login_params
    params.permit(:email, :password)
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