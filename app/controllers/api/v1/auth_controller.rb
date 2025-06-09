# Универсальный контроллер для аутентификации всех типов пользователей
class Api::V1::AuthController < ApplicationController
  # Не требуем авторизации для входа
  skip_before_action :authenticate_request, only: [:login]
      
      # POST /api/v1/auth/login
  # Универсальный вход для всех ролей пользователей
      def login
    begin
      # Ищем пользователя по email или телефону
      user = find_user_by_credentials(login_params[:login])
      
      unless user
        render json: { error: 'Пользователь не найден' }, status: :not_found
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
      access_token = Auth::JsonWebToken.encode_access_token(user_id: user.id, role: user.role.name)
      refresh_token = Auth::JsonWebToken.encode_refresh_token(user_id: user.id, role: user.role.name)

      # Формируем ответ в зависимости от роли
      response_data = {
        message: 'Вход выполнен успешно',
        user: {
          id: user.id,
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name,
          phone: user.phone,
          role: user.role.name,
          is_active: user.is_active?
        },
        tokens: {
          access: access_token,
          refresh: refresh_token
        }
      }

      # Добавляем специфичные для роли данные
      case user.role.name
      when 'client'
        if user.client
          response_data[:client] = {
            id: user.client.id,
            preferred_notification_method: user.client.preferred_notification_method,
            total_bookings: user.client.total_bookings,
            completed_bookings: user.client.completed_bookings
          }
        end
      when 'admin', 'manager', 'partner', 'operator'
        # Для административных ролей можно добавить дополнительную информацию
        response_data[:admin_info] = {
          role_permissions: get_role_permissions(user.role.name),
          last_login: user.last_login
        }
      end

      render json: response_data, status: :ok
    rescue StandardError => e
      Rails.logger.error "Ошибка универсального входа: #{e.message}"
      render json: { error: 'Внутренняя ошибка сервера' }, status: :internal_server_error
        end
      end
      
      # POST /api/v1/auth/logout
  # Универсальный выход из системы
      def logout
    # В JWT нет server-side логаута, токен просто перестают использовать на клиенте
    render json: { message: 'Выход выполнен успешно' }, status: :ok
  end

  # GET /api/v1/auth/me
  # Получение информации о текущем пользователе (любой роли)
  def me
    response_data = {
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
      }
    }

    # Добавляем специфичные для роли данные
    case current_user.role.name
    when 'client'
      if current_user.client
        response_data[:client] = {
          id: current_user.client.id,
          preferred_notification_method: current_user.client.preferred_notification_method,
          total_bookings: current_user.client.total_bookings,
          completed_bookings: current_user.client.completed_bookings,
          average_rating_given: current_user.client.average_rating_given
        }
      end
    when 'admin', 'manager', 'partner', 'operator'
      response_data[:admin_info] = {
        role_permissions: get_role_permissions(current_user.role.name),
        last_login: current_user.last_login
      }
    end

    render json: response_data, status: :ok
      end
      
      private
      
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

  def get_role_permissions(role_name)
    permissions = {
      'admin' => ['full_access', 'user_management', 'system_config'],
      'manager' => ['service_point_management', 'booking_management'],
      'partner' => ['own_service_points', 'booking_view'],
      'operator' => ['booking_management', 'client_support'],
      'client' => ['booking_create', 'profile_management']
    }
    permissions[role_name] || []
  end
end
