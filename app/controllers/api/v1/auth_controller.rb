# Универсальный контроллер для аутентификации всех типов пользователей
require_relative '../../../services/auth/json_web_token'

module Api
  module V1
    class AuthController < BaseController
      # Не требуем авторизации для входа и обновления токена
      skip_before_action :authenticate_request, only: [:login, :refresh]
      
      # POST /api/v1/auth/login
      # Универсальный вход для всех ролей пользователей
      def login
        auth_params = params.require(:auth)
        login = auth_params[:login] || auth_params[:email]  # ✅ Поддерживаем и старый формат
        password = auth_params[:password]
        
        Rails.logger.info("Auth#login: Attempting login for: #{login}")
        Rails.logger.info("Auth#login: cookies available: #{cookies.present?}")
        
        unless login.present? && password.present?
          render json: { error: 'Необходимо указать логин и пароль' }, status: :unprocessable_entity
          return
        end
        
        # ✅ Поиск пользователя по email или телефону
        user = User.find_by_login(login)
        
        unless user
          Rails.logger.info("Auth#login: User not found for login: #{login}")
          render json: { error: 'Пользователь не найден' }, status: :not_found
          return
        end

        unless user.authenticate(password)
          Rails.logger.info("Auth#login: Authentication failed for user: #{user.id}")
          render json: { error: 'Неверный логин или пароль' }, status: :unauthorized
          return
        end

        unless user.is_active?
          Rails.logger.info("Auth#login: User account is inactive: #{user.id}")
          render json: { error: 'Аккаунт заблокирован' }, status: :forbidden
          return
        end

        # Обновляем время последнего входа
        user.update_last_login!

        # Генерируем JWT токены
        access_token = Auth::JsonWebToken.encode_access_token(user_id: user.id)
        refresh_token = Auth::JsonWebToken.encode_refresh_token(user_id: user.id)
        
        Rails.logger.info("Auth#login: Generated tokens for user: #{user.id}")
        
        # Устанавливаем refresh токен в HttpOnly куки
        cookies.encrypted[:refresh_token] = {
          value: refresh_token,
          httponly: true,
          secure: Rails.env.production?,
          same_site: :lax,
          expires: 30.days.from_now,
          path: '/'
        }

        render json: {
          user: {
            id: user.id,
            email: user.email,
            phone: user.phone,
            first_name: user.first_name,
            last_name: user.last_name,
            email_verified: user.email_verified,
            phone_verified: user.phone_verified,
            role: user.role.name,
            is_active: user.is_active?,
            client_id: user.client&.id
          },
          access_token: access_token,
          message: 'Вход выполнен успешно'
        }, status: :ok
      end
      
      # POST /api/v1/auth/refresh
      # Обновление access токена через refresh токен
      def refresh
        refresh_token = cookies.encrypted[:refresh_token]
        
        unless refresh_token
          render json: { error: 'Refresh токен не найден' }, status: :unauthorized
          return
        end
        
        begin
          decoded_token = Auth::JsonWebToken.decode_refresh_token(refresh_token)
          user = User.find(decoded_token[:user_id])
          
          unless user&.is_active?
            render json: { error: 'Пользователь неактивен' }, status: :unauthorized
            return
          end
          
          # Генерируем новый access токен
          new_access_token = Auth::JsonWebToken.encode_access_token(user_id: user.id)
          
          render json: {
            access_token: new_access_token,
            user: {
              id: user.id,
              email: user.email,
              phone: user.phone,
              first_name: user.first_name,
              last_name: user.last_name,
              role: user.role.name,
              client_id: user.client&.id
            }
          }, status: :ok
        rescue JWT::DecodeError, ActiveRecord::RecordNotFound => e
          Rails.logger.error "Auth#refresh error: #{e.message}"
          render json: { error: 'Недействительный refresh токен' }, status: :unauthorized
        end
      end
      
      # POST /api/v1/auth/logout
      # Выход из системы
      def logout
        # Удаляем refresh токен из cookies
        cookies.delete(:refresh_token)
        
        Rails.logger.info("Auth#logout: User logged out successfully")
        render json: { message: 'Выход выполнен успешно' }, status: :ok
      end
      
      # GET /api/v1/auth/me
      # Получение информации о текущем пользователе
      def me
        response_data = {
          user: {
            id: current_user.id,
            email: current_user.email,
            phone: current_user.phone,
            first_name: current_user.first_name,
            last_name: current_user.last_name,
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
      
      # PUT /api/v1/auth/profile
      # Обновление профиля текущего пользователя
      def update_profile
        user_params = params.require(:user).permit(:first_name, :last_name, :email, :phone)
        
        if current_user.update(user_params)
          response_data = {
            user: {
              id: current_user.id,
              email: current_user.email,
              phone: current_user.phone,
              first_name: current_user.first_name,
              last_name: current_user.last_name,
              email_verified: current_user.email_verified,
              phone_verified: current_user.phone_verified,
              role: current_user.role.name,
              is_active: current_user.is_active?,
              client_id: current_user.client&.id
            }
          }
          
          render json: response_data, status: :ok
        else
          render json: { errors: current_user.errors }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/auth/me/cars
      # Получение автомобилей текущего клиента
      def my_cars
        unless current_user.client?
          render json: { error: 'Доступно только для клиентов' }, status: :forbidden
          return
        end

        cars = current_user.client.cars.includes(:brand, :model, :car_type)
        render json: cars, each_serializer: ClientCarSerializer
      end

      # POST /api/v1/auth/me/cars
      # Создание автомобиля для текущего клиента
      def create_car
        unless current_user.client?
          render json: { error: 'Доступно только для клиентов' }, status: :forbidden
          return
        end

        car_params = params.require(:car).permit(:brand_id, :model_id, :car_type_id, :year, :license_plate, :is_primary)
        car = current_user.client.cars.build(car_params)

        if car.save
          render json: car, serializer: ClientCarSerializer, status: :created
        else
          render json: { errors: car.errors }, status: :unprocessable_entity
        end
      end

      private

      def get_role_permissions(role_name)
        case role_name
        when 'admin'
          ['manage_users', 'manage_partners', 'manage_service_points', 'view_analytics', 'manage_system']
        when 'manager'
          ['manage_bookings', 'view_analytics', 'manage_service_points']
        when 'partner'
          ['manage_own_service_points', 'view_own_analytics', 'manage_bookings']
        when 'operator'
          ['manage_bookings', 'view_schedule']
        else
          []
        end
      end
    end
  end
end
