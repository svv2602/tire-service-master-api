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
        render json: { error: I18n.t('errors.internal') }, status: :internal_server_error
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
        cookies[:refresh_token] = {
          value: refresh_token,
          httponly: true,
          secure: Rails.env.production?,
          same_site: :lax,
          expires: 30.days.from_now,
          path: '/'
        }
        
        # Устанавливаем access токен в HttpOnly куки для автоматической аутентификации
        cookies[:access_token] = {
          value: access_token,
          httponly: true,
          secure: Rails.env.production?,
          same_site: :lax,
          expires: 1.hour.from_now,
          path: '/'
        }
        
        # Возвращаем ответ в формате, соответствующем тестам
        render json: {
          message: I18n.t('auth.messages.registration_success'),
          user: user.as_json(only: [:id, :email, :first_name, :last_name, :phone]),
          client: client.as_json(only: [:id, :preferred_notification_method]),
          tokens: {
            access: access_token
            # Refresh токен теперь в куки
          }
        }, status: :created
      else
        render json: { 
          error: I18n.t('auth.errors.registration_failed'), 
          details: user.errors.full_messages 
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error "Ошибка регистрации клиента: #{e.message}"
      render json: { error: I18n.t('errors.internal') }, status: :internal_server_error
    end
  end

  # POST /api/v1/clients/login
  # Вход клиента в систему
  def login
    begin
      # Ищем пользователя по email
      user = User.find_by(email: login_params[:email])
      
      unless user
        render json: { error: I18n.t('auth.errors.user_not_found') }, status: :not_found
        return
      end

      # Проверяем что это клиент
      unless user.client?
        render json: { error: I18n.t('auth.errors.clients_only') }, status: :forbidden
        return
      end

      # Проверяем пароль
      unless user.authenticate(login_params[:password])
        render json: { error: I18n.t('auth.errors.invalid_credentials') }, status: :unauthorized
        return
      end

      # Проверяем что аккаунт активен
      unless user.is_active?
        render json: { error: I18n.t('auth.errors.account_blocked') }, status: :forbidden
        return
      end

      # Обновляем время последнего входа
      user.update_last_login!

      # Генерируем JWT токены
      access_token = Auth::JsonWebToken.encode_access_token(user_id: user.id)
      refresh_token = Auth::JsonWebToken.encode_refresh_token(user_id: user.id)
      
      # Устанавливаем refresh токен в HttpOnly куки
      cookies[:refresh_token] = {
        value: refresh_token,
        httponly: true,
        secure: Rails.env.production?,
        same_site: :lax,
        expires: 30.days.from_now,
        path: '/'
      }
      
      # Устанавливаем access токен в HttpOnly куки для автоматической аутентификации
      cookies[:access_token] = {
        value: access_token,
        httponly: true,
        secure: Rails.env.production?,
        same_site: :lax,
        expires: 1.hour.from_now,
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
        message: I18n.t('auth.messages.login_success')
      }, status: :ok
    rescue StandardError => e
      Rails.logger.error "Ошибка входа клиента: #{e.message}"
      render json: { error: I18n.t('errors.internal') }, status: :internal_server_error
    end
  end

  # POST /api/v1/clients/logout
  # Выход из системы
  def logout
    # ✅ Удаляем ВСЕ куки при выходе
    cookies.delete(:refresh_token)
    cookies.delete(:access_token)
    
    Rails.logger.info("ClientAuth#logout: User logged out successfully, all cookies cleared")
    render json: { message: I18n.t('auth.messages.logout_success') }, status: :ok
  end

  # GET /api/v1/clients/me
  # Получение информации о текущем клиенте
  def me
    unless current_user&.client?
      render json: { error: I18n.t('auth.errors.clients_only') }, status: :forbidden
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
    # Для регистрации клиентов email не обязателен
    permitted_params = params.require(:user).permit(:first_name, :last_name, :email, :phone, :password, :password_confirmation)
    
    # Убираем email, если он фиктивный (временный)
    if permitted_params[:email]&.include?('@temp.local')
      permitted_params.delete(:email)
    end
    
    permitted_params
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