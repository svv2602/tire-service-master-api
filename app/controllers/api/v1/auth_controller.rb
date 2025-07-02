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
        email = auth_params[:email] || auth_params[:login]
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
          
          # Универсальные опции для refresh_token
          cookie_options = {
            value: refresh_token,
            httponly: true,
            expires: 30.days.from_now,
            path: '/'
          }
          if Rails.env.production?
            cookie_options[:secure] = true
            cookie_options[:same_site] = :none
          else
            cookie_options[:secure] = false
            cookie_options[:same_site] = :none
          end
          
          # Используем несколько имён cookie для большей совместимости
          cookies.encrypted[:refresh_token] = cookie_options
          cookies.encrypted[:_tire_service_refresh] = cookie_options
          cookies.encrypted[:_session] = cookie_options
          
          Rails.logger.info("Auth#login: All refresh cookies set with names: refresh_token, _tire_service_refresh, _session")
          
          Rails.logger.info("Auth#login: Cookies set (access + refresh), preparing response")
          
          # Создаем пользовательский JSON с добавлением роли
          user_json = user.as_json(only: [:id, :email, :first_name, :last_name, :is_active])
          user_json['role'] = user.role.name if user.role
          
          render json: {
            message: 'Авторизация успешна',
            user: user_json,
            tokens: {
              access: access_token,
              refresh: refresh_token
            }
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
          # Генерируем новый refresh_token и кладём в куку (сквозная ротация)
          new_refresh_token = Auth::JsonWebToken.encode_refresh_token(user_id: Auth::JsonWebToken.decode(refresh_token)['user_id'])
          # Универсальные опции для refresh_token (refresh)
          cookie_options = {
            value: new_refresh_token,
            httponly: true,
            expires: 30.days.from_now,
            path: '/'
          }
          if Rails.env.production?
            cookie_options[:secure] = true
            cookie_options[:same_site] = :lax
          else
            cookie_options[:secure] = false
            cookie_options[:same_site] = :lax
          end
          cookies.encrypted[:refresh_token] = cookie_options
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
      
      # PUT /api/v1/auth/profile
      # Обновление профиля текущего пользователя
      def update_profile
        user_params = params.require(:user).permit(:first_name, :last_name, :email, :phone)
        
        if current_user.update(user_params)
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

        car = current_user.client.cars.build(car_params)

        # Проверяем, нужно ли установить автомобиль как основной при создании
        if car_params[:is_primary] == true || car_params[:is_primary] == 'true'
          # Сначала сохраняем автомобиль без флага is_primary
          car.is_primary = false
          if car.save
            # Затем безопасно устанавливаем как основной
            car.mark_as_primary!
            render json: car.reload, serializer: ClientCarSerializer, status: :created
          else
            render json: { errors: car.errors }, status: :unprocessable_entity
          end
        else
          # Обычное создание без установки как основной
          if car.save
            render json: car, serializer: ClientCarSerializer, status: :created
          else
            render json: { errors: car.errors }, status: :unprocessable_entity
          end
        end
      end

      # PATCH /api/v1/auth/me/cars/:car_id
      # Обновление автомобиля текущего клиента
      def update_car
        unless current_user.client?
          render json: { error: 'Доступно только для клиентов' }, status: :forbidden
          return
        end

        car = current_user.client.cars.find(params[:car_id])

        # Проверяем, нужно ли установить автомобиль как основной
        if car_params[:is_primary] == true || car_params[:is_primary] == 'true'
          # Используем безопасный метод для установки основного автомобиля
          car.assign_attributes(car_params.except(:is_primary))
          if car.valid?
            car.mark_as_primary! unless car.is_primary?
            render json: car.reload, serializer: ClientCarSerializer
          else
            render json: { errors: car.errors }, status: :unprocessable_entity
          end
        else
          # Обычное обновление без изменения статуса основного автомобиля
          if car.update(car_params)
            render json: car, serializer: ClientCarSerializer
          else
            render json: { errors: car.errors }, status: :unprocessable_entity
          end
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Автомобиль не найден' }, status: :not_found
      end

      # DELETE /api/v1/auth/me/cars/:car_id
      # Удаление автомобиля текущего клиента
      def delete_car
        unless current_user.client?
          render json: { error: 'Доступно только для клиентов' }, status: :forbidden
          return
        end

        car = current_user.client.cars.find(params[:car_id])

        if car.bookings.exists?
          # Если есть бронирования с этой машиной, просто помечаем как неактивную
          if car.update(is_active: false)
            render json: { message: 'Автомобиль был помечен как неактивный' }
          else
            render json: { errors: car.errors }, status: :unprocessable_entity
          end
        else
          # Если бронирований нет, можем полностью удалить
          if car.destroy
            render json: { message: 'Автомобиль был успешно удален' }
          else
            render json: { errors: car.errors }, status: :unprocessable_entity
          end
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Автомобиль не найден' }, status: :not_found
      end
      
      private
      
      def auth_params
        params.permit(:email, :password)
      end

      def car_params
        params.require(:car).permit(:brand_id, :model_id, :year, :license_plate, :car_type_id, :is_primary)
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
