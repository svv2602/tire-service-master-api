# Универсальный контроллер для аутентификации всех типов пользователей
module Api
  module V1
    class AuthController < BaseController
      # Не требуем авторизации для входа и обновления токена
      skip_before_action :authenticate_request, only: [:login, :refresh]
      
      # POST /api/v1/auth/login
      # Универсальный вход для всех ролей пользователей
      def login
        user = User.find_by(email: params[:email])
        
        if user&.authenticate(params[:password])
          access_token = Auth::JsonWebToken.encode_access_token(user_id: user.id)
          refresh_token = Auth::JsonWebToken.encode_refresh_token(user_id: user.id)
          
          # Создаем пользовательский JSON с добавлением роли
          user_json = user.as_json(only: [:id, :email, :first_name, :last_name, :is_active])
          user_json['role'] = user.role.name if user.role
          
          render json: { 
            tokens: { 
              access: access_token,
              refresh: refresh_token
            },
            user: user_json
          }
        else
          render json: { error: 'Неверные учетные данные' }, status: :unauthorized
        end
      end
      
      # POST /api/v1/auth/refresh
      # Обновление токена доступа
      def refresh
        begin
          refresh_token = request.headers['Refresh-Token'] || params[:refresh_token]
          raise Auth::TokenInvalidError, 'Refresh token is required' if refresh_token.blank?
          
          access_token = Auth::JsonWebToken.refresh_access_token(refresh_token)
          render json: { 
            tokens: { 
              access: access_token,
              refresh: refresh_token
            }
          }
        rescue Auth::TokenExpiredError, Auth::TokenInvalidError, Auth::TokenRevokedError => e
          render json: { error: e.message }, status: :unauthorized
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
