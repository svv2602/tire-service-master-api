# Универсальный контроллер для аутентификации всех типов пользователей
module Api
  module V1
    class AuthController < BaseController
      # Не требуем авторизации для входа и обновления токена
      skip_before_action :authenticate_request, only: [:login, :refresh]
      
      # POST /api/v1/auth/login
      # Универсальный вход для всех ролей пользователей
      def login
        auth_params = params.require(:auth)
        email = auth_params[:login]
        password = auth_params[:password]
        
        user = User.find_by(email: email)
        
        Rails.logger.info("Auth#login: Attempting login for email: #{email}")
        Rails.logger.info("Auth#login: cookies available: #{cookies.present?}")
        
        if user&.authenticate(password)
          access_token = Auth::JsonWebToken.encode_access_token(user_id: user.id)
          refresh_token = Auth::JsonWebToken.encode_refresh_token(user_id: user.id)
          
          Rails.logger.info("Auth#login: Authentication successful, setting cookies")
          
          # Устанавливаем оба токена в HttpOnly куки
          cookies.encrypted[:access_token] = {
            value: access_token,
            httponly: true,
            secure: Rails.env.production?,
            same_site: :lax,
            expires: 1.hour.from_now
          }
          
          cookies.encrypted[:refresh_token] = {
            value: refresh_token,
            httponly: true,
            secure: Rails.env.production?,
            same_site: :lax, # Используем lax для лучшей совместимости с SPA
            expires: 30.days.from_now
          }
          
          Rails.logger.info("Auth#login: Cookies set (access + refresh), preparing response")
          
          # Создаем пользовательский JSON с добавлением роли
          user_json = user.as_json(only: [:id, :email, :first_name, :last_name, :is_active])
          user_json['role'] = user.role.name if user.role
          
          render json: { 
            message: 'Авторизация успешна',
            user: user_json
          }
        else
          Rails.logger.info("Auth#login: Authentication failed")
          render json: { error: 'Неверные учетные данные' }, status: :unauthorized
        end
      end
      
      # POST /api/v1/auth/refresh
      # Обновление токена доступа
      def refresh
        begin
          # Получаем refresh токен из куки вместо заголовка
          refresh_token = cookies.encrypted[:refresh_token]
          
          raise Auth::TokenInvalidError, 'Refresh token is required' if refresh_token.blank?
          
          access_token = Auth::JsonWebToken.refresh_access_token(refresh_token)
          
          render json: { 
            tokens: { 
              access: access_token
            }
          }
        rescue Auth::TokenExpiredError, Auth::TokenInvalidError, Auth::TokenRevokedError => e
          # Удаляем куки при ошибке
          cookies.delete(:refresh_token)
          render json: { error: e.message }, status: :unauthorized
        end
      end
      
      # POST /api/v1/auth/logout
      # Универсальный выход из системы
      def logout
        # Добавляем логирование для отладки
        Rails.logger.info("Auth#logout: Attempting logout")
        Rails.logger.info("Auth#logout: cookies available: #{cookies.present?}")
        
        # Удаляем оба auth куки при выходе
        cookies.delete(:access_token)
        cookies.delete(:refresh_token)
        
        Rails.logger.info("Auth#logout: Auth cookies deleted, sending success response")
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
            is_active: current_user.is_active?,
            client_id: current_user.client&.id
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
      
      def auth_params
        params.permit(:email, :password)
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
  end
end
