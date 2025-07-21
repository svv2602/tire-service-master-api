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
          render json: { error: I18n.t('auth.errors.credentials_required') }, status: :unprocessable_entity
          return
        end
        
        # ✅ Поиск пользователя по email или телефону
        user = User.find_by_login(login)
        
        unless user
          Rails.logger.info("Auth#login: User not found for login: #{login}")
          render json: { error: I18n.t('auth.errors.user_not_found') }, status: :not_found
          return
        end

        unless user.authenticate(password)
          Rails.logger.info("Auth#login: Authentication failed for user: #{user.id}")
          render json: { error: I18n.t('auth.errors.invalid_credentials') }, status: :unauthorized
          return
        end

        unless user.is_active?
          Rails.logger.info("Auth#login: User account is inactive: #{user.id}")
          render json: { error: I18n.t('auth.errors.account_blocked') }, status: :forbidden
          return
        end

        # Обновляем время последнего входа
        user.update_last_login!

        # ✅ Очищаем старые куки перед установкой новых
        cookies.delete(:refresh_token)
        cookies.delete(:access_token)

        # Генерируем JWT токены
        access_token = Auth::JsonWebToken.encode_access_token(user_id: user.id)
        refresh_token = Auth::JsonWebToken.encode_refresh_token(user_id: user.id)
        
        Rails.logger.info("Auth#login: Generated tokens for user: #{user.id}")
        
        # Устанавливаем refresh токен в HttpOnly куки
        cookies[:refresh_token] = {
          value: refresh_token,
          httponly: true,
          secure: Rails.env.production?,
          same_site: :lax,
          expires: 30.days.from_now,
          path: '/'
        }

        # ✅ Также устанавливаем access токен в куки для более стабильной авторизации
        cookies[:access_token] = {
          value: access_token,
          httponly: true,
          secure: Rails.env.production?,
          same_site: :lax,
          expires: 1.hour.from_now,
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
          message: I18n.t('auth.messages.login_success')
        }, status: :ok
      end
      
      # POST /api/v1/auth/refresh
      # Обновление access токена через refresh токен
      def refresh
        refresh_token = cookies[:refresh_token]
        
        unless refresh_token
          render json: { error: I18n.t('auth.errors.refresh_token_not_found') }, status: :unauthorized
          return
        end
        
        begin
          decoded_token = Auth::JsonWebToken.decode_refresh_token(refresh_token)
          user = User.find(decoded_token[:user_id])
          
          unless user&.is_active?
            render json: { error: I18n.t('auth.errors.user_inactive') }, status: :unauthorized
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
          render json: { error: I18n.t('auth.errors.invalid_refresh_token') }, status: :unauthorized
        end
      end
      
      # POST /api/v1/auth/logout
      # Выход из системы
      def logout
        # ✅ Удаляем ВСЕ куки при выходе
        cookies.delete(:refresh_token)
        cookies.delete(:access_token)
        
        Rails.logger.info("Auth#logout: User logged out successfully, all cookies cleared")
        render json: { message: I18n.t('auth.messages.logout_success') }, status: :ok
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
            },
            message: I18n.t('auth.messages.profile_updated')
          }
          
          render json: response_data, status: :ok
        else
          render json: { errors: current_user.errors }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/auth/me/cars
      # Получение автомобилей текущего пользователя (создаем клиентский профиль если нужно)
      def my_cars
        # Автоматически создаем клиентский профиль для всех ролей
        ensure_client_profile
        
        cars = current_user.client.cars.includes(:brand, :model, :car_type)
        render json: cars, each_serializer: ClientCarSerializer
      end

      # POST /api/v1/auth/me/cars
      # Создание автомобиля для текущего пользователя (создаем клиентский профиль если нужно)
      def create_car
        # Автоматически создаем клиентский профиль для всех ролей
        ensure_client_profile

        car_params = params.require(:car).permit(:brand_id, :model_id, :car_type_id, :year, :license_plate, :is_primary)
        car = current_user.client.cars.build(car_params)

        # Если передан email и у пользователя нет email, добавляем его
        if params[:car][:email].present? && (current_user.email.blank? || current_user.email.include?("guest_"))
          current_user.update(email: params[:car][:email])
          Rails.logger.info("Updated user #{current_user.id} email to #{params[:car][:email]}")
        end

        if car.save
          render json: { 
            car: ClientCarSerializer.new(car).as_json, 
            message: I18n.t('auth.messages.car_created')
          }, status: :created
        else
          render json: { errors: car.errors }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/auth/me/cars/:id
      # Обновление автомобиля текущего пользователя
      def update_car
        # Автоматически создаем клиентский профиль для всех ролей (если каким-то образом его нет)
        ensure_client_profile

        car = current_user.client.cars.find(params[:id])
        car_params = params.require(:car).permit(:brand_id, :model_id, :car_type_id, :year, :license_plate, :is_primary)

        if car.update(car_params)
          render json: { 
            car: ClientCarSerializer.new(car).as_json, 
            message: I18n.t('auth.messages.car_updated')
          }, status: :ok
        else
          render json: { errors: car.errors }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: I18n.t('auth.errors.car_not_found') }, status: :not_found
      end

      # DELETE /api/v1/auth/me/cars/:id
      # Удаление автомобиля текущего пользователя
      def delete_car
        # Автоматически создаем клиентский профиль для всех ролей (если каким-то образом его нет)
        ensure_client_profile

        car = current_user.client.cars.find(params[:id])

        if car.destroy
          render json: { message: I18n.t('auth.messages.car_deleted') }, status: :ok
        else
          render json: { errors: car.errors }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: I18n.t('auth.errors.car_not_found') }, status: :not_found
      end

      # ✅ НОВЫЕ ЭНДПОИНТЫ ДЛЯ ИЗБРАННЫХ СЕРВИСНЫХ ТОЧЕК

      # GET /api/v1/auth/me/favorite_points
      # Получение избранных сервисных точек текущего пользователя
      def my_favorite_points
        # Автоматически создаем клиентский профиль для всех ролей
        ensure_client_profile
        
        favorite_points = current_user.client.favorite_service_points
                                           .available_for_booking
                                           .includes(:city, :partner, :photos)
        
        # Преобразуем в формат, аналогичный ClientFavoritePointsController#index
        favorites_data = favorite_points.map do |service_point|
          {
            id: current_user.client.favorite_points.find_by(service_point: service_point)&.id,
            service_point: {
              id: service_point.id,
              name: service_point.name,
              address: service_point.address,
              description: service_point.description,
              city: {
                id: service_point.city.id,
                name: service_point.city.name,
                region: service_point.city.region&.name
              },
              partner: {
                id: service_point.partner.id,
                name: service_point.partner.company_name
              },
              contact_phone: service_point.contact_phone,
              average_rating: service_point.average_rating&.round(1) || 0.0,
              reviews_count: service_point.reviews.count,
              posts_count: service_point.posts_count,
              work_status: service_point.work_status,
              photos: service_point.photos.sorted.limit(3).map do |photo|
                {
                  id: photo.id,
                  url: photo.file.attached? ? Rails.application.routes.url_helpers.url_for(photo.file) : nil,
                  description: photo.description,
                  is_main: photo.is_main
                }
              end
            }
          }
        end
        
        render json: favorites_data
      end

      # GET /api/v1/auth/me/favorite_points/by_category
      # Получение избранных точек текущего пользователя, сгруппированных по категориям
      def my_favorite_points_by_category
        # Автоматически создаем клиентский профиль для всех ролей
        ensure_client_profile
        
        favorite_points = current_user.client.favorite_service_points
                                           .available_for_booking
                                           .includes(:city, :partner, :photos, service_posts: :service_category)
        
        if favorite_points.empty?
          return render json: {
            has_favorites: false,
            categories_with_favorites: []
          }
        end
        
        # Группируем по категориям
        categories_with_favorites = {}
        
        favorite_points.each do |service_point|
          service_point.service_posts.active.includes(:service_category).each do |post|
            category = post.service_category
            
            categories_with_favorites[category.id] ||= {
              category_id: category.id,
              category_name: category.name,
              service_points: []
            }
            
            # Добавляем точку только если её еще нет в этой категории
            unless categories_with_favorites[category.id][:service_points].any? { |sp| sp[:id] == service_point.id }
              main_photo = service_point.photos.main.first || service_point.photos.first
              
              categories_with_favorites[category.id][:service_points] << {
                id: service_point.id,
                name: service_point.name,
                address: service_point.address,
                city_name: service_point.city.name,
                partner_name: service_point.partner.company_name,
                photo_url: main_photo&.file&.attached? ? Rails.application.routes.url_helpers.url_for(main_photo.file) : nil,
                average_rating: service_point.average_rating&.round(1) || 0.0
              }
            end
          end
        end
        
        render json: {
          has_favorites: true,
          categories_with_favorites: categories_with_favorites.values
        }
      end

      # POST /api/v1/auth/me/favorite_points
      # Добавление сервисной точки в избранное для текущего пользователя
      def add_to_my_favorites
        # Автоматически создаем клиентский профиль для всех ролей
        ensure_client_profile
        
        service_point = ServicePoint.find(params[:service_point_id])
        
        # Проверяем, что точка доступна для бронирования
        unless service_point.can_accept_bookings?
          return render json: { 
            error: 'Данная сервисная точка недоступна для добавления в избранное',
            reason: service_point.display_status
          }, status: :unprocessable_entity
        end
        
        # Проверяем, не добавлена ли уже точка в избранное
        if current_user.client.favorite_service_points.exists?(service_point.id)
          return render json: { 
            error: 'Данная сервисная точка уже добавлена в избранное'
          }, status: :unprocessable_entity
        end
        
        favorite_point = current_user.client.favorite_points.build(service_point: service_point)
        
        if favorite_point.save
          # Логируем действие
          Rails.logger.info "Пользователь #{current_user.id} (роль: #{current_user.role.name}) добавил сервисную точку #{service_point.id} в избранное"
          
          render json: {
            id: favorite_point.id,
            service_point: {
              id: service_point.id,
              name: service_point.name,
              address: service_point.address,
              city: service_point.city.name
            },
            added_at: favorite_point.created_at,
            message: 'Сервисная точка успешно добавлена в избранное'
          }, status: :created
        else
          render json: { 
            errors: favorite_point.errors,
            message: 'Не удалось добавить сервисную точку в избранное'
          }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Сервисная точка не найдена' }, status: :not_found
      end

      # DELETE /api/v1/auth/me/favorite_points/:id
      # Удаление сервисной точки из избранного для текущего пользователя
      def remove_from_my_favorites
        # Автоматически создаем клиентский профиль для всех ролей
        ensure_client_profile
        
        favorite_point = current_user.client.favorite_points.find(params[:id])
        service_point_name = favorite_point.service_point.name
        
        if favorite_point.destroy
          Rails.logger.info "Пользователь #{current_user.id} (роль: #{current_user.role.name}) удалил сервисную точку #{favorite_point.service_point_id} из избранного"
          
          render json: { 
            message: "#{service_point_name} удалена из избранного"
          }
        else
          render json: { 
            errors: favorite_point.errors,
            message: 'Не удалось удалить сервисную точку из избранного'
          }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Избранная сервисная точка не найдена' }, status: :not_found
      end

      # GET /api/v1/auth/me/favorite_points/check/:service_point_id
      # Проверка, является ли сервисная точка избранной для текущего пользователя
      def check_is_favorite
        # Автоматически создаем клиентский профиль для всех ролей
        ensure_client_profile
        
        service_point_id = params[:service_point_id]
        favorite_point = current_user.client.favorite_points.find_by(service_point_id: service_point_id)
        
        render json: {
          is_favorite: favorite_point.present?,
          favorite_id: favorite_point&.id
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Сервисная точка не найдена' }, status: :not_found
      end

      private

      # Автоматически создает клиентский профиль для всех ролей пользователей
      # Это позволяет администраторам, партнерам и другим ролям сохранять свои автомобили
      def ensure_client_profile
        return if current_user.client.present?
        
        Rails.logger.info("Создаем клиентский профиль для пользователя #{current_user.id} (роль: #{current_user.role.name})")
        
        # Создаем клиентский профиль с настройками по умолчанию
        Client.create!(
          user: current_user,
          preferred_notification_method: 'email',
          marketing_consent: false
        )
        
        # Обновляем ассоциацию в текущем объекте
        current_user.reload
        
        Rails.logger.info("Клиентский профиль создан для пользователя #{current_user.id}")
      rescue => e
        Rails.logger.error "Ошибка создания клиентского профиля: #{e.message}"
        raise
      end

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
