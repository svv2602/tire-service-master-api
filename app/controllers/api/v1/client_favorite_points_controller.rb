module Api
  module V1
    class ClientFavoritePointsController < ApiController
      skip_after_action :verify_authorized
      before_action :set_client
      before_action :set_favorite_point, only: [:show, :destroy]
      
      # GET /api/v1/clients/:client_id/favorite_points
      # Получение списка любимых сервисных точек клиента
      def index
        # Доступно для всех авторизованных пользователей
        return render json: { error: 'Unauthorized' }, status: 401 unless current_user
        
        @favorite_points = @client.favorite_service_points.available_for_booking
                                  .includes(:city, :partner, :photos, service_posts: :service_category)
        
        # Группируем любимые точки по категориям услуг
        favorites_by_category = {}
        
        @favorite_points.each do |service_point|
          # Получаем все категории услуг, доступные в данной сервисной точке
          categories = service_point.service_posts.active
                                  .joins(:service_category)
                                  .select('service_categories.id, service_categories.name')
                                  .distinct
          
          categories.each do |category|
            category_id = category.id
            category_name = category.name
            
            favorites_by_category[category_id] ||= {
              category: {
                id: category_id,
                name: category_name
              },
              service_points: []
            }
            
            # Добавляем сервисную точку только если её еще нет в этой категории
            unless favorites_by_category[category_id][:service_points].any? { |sp| sp[:id] == service_point.id }
              favorites_by_category[category_id][:service_points] << {
                id: service_point.id,
                name: service_point.name,
                address: service_point.address,
                city: {
                  id: service_point.city.id,
                  name: service_point.city.name
                },
                partner: {
                  id: service_point.partner.id,
                  name: service_point.partner.company_name
                },
                contact_phone: service_point.contact_phone,
                average_rating: service_point.average_rating&.round(1) || 0.0,
                posts_count: service_point.posts_count,
                photos: service_point.photos.sorted.limit(1).map do |photo|
                  {
                    id: photo.id,
                    url: photo.file.attached? ? Rails.application.routes.url_helpers.url_for(photo.file) : nil,
                    is_main: photo.is_main
                  }
                end,
                added_to_favorites_at: @client.favorite_points.find_by(service_point: service_point)&.created_at
              }
            end
          end
        end
        
        render json: {
          data: favorites_by_category.values,
          total_favorites: @favorite_points.count,
          categories_count: favorites_by_category.keys.count
        }
      end

      # GET /api/v1/clients/:client_id/favorite_points/by_category
      # Получение любимых точек, сгруппированных по категориям (для быстрого бронирования)
      def by_category
        # Доступно для всех авторизованных пользователей
        return render json: { error: 'Unauthorized' }, status: 401 unless current_user
        
        @favorite_points = @client.favorite_service_points.available_for_booking
                                  .includes(:city, :partner, :photos, service_posts: :service_category)
        
        # Если нет любимых точек
        if @favorite_points.empty?
          return render json: {
            has_favorites: false,
            categories_with_favorites: []
          }
        end
        
        # Группируем по категориям
        categories_with_favorites = {}
        
        @favorite_points.each do |service_point|
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
      
      # GET /api/v1/clients/:client_id/favorite_points/:id
      # Получение детальной информации о любимой сервисной точке
      def show
        # Доступно для всех авторизованных пользователей
        return render json: { error: 'Unauthorized' }, status: 401 unless current_user
        service_point = @favorite_point.service_point
        
        render json: {
          id: @favorite_point.id,
          added_at: @favorite_point.created_at,
          service_point: {
            id: service_point.id,
            name: service_point.name,
            description: service_point.description,
            address: service_point.address,
            city: {
              id: service_point.city.id,
              name: service_point.city.name,
              region: service_point.city.region.name
            },
            partner: {
              id: service_point.partner.id,
              name: service_point.partner.company_name
            },
            contact_phone: service_point.contact_phone,
            average_rating: service_point.average_rating&.round(1) || 0.0,
            reviews_count: service_point.reviews.count,
            posts_count: service_point.posts_count,
            can_accept_bookings: service_point.can_accept_bookings?,
            
            # Категории услуг доступные в этой точке
            available_categories: service_point.service_posts.active
                                             .joins(:service_category)
                                             .select('service_categories.id, service_categories.name, service_categories.description')
                                             .distinct
                                             .map do |category|
              {
                id: category.id,
                name: category.name,
                description: category.description
              }
            end,
            
            photos: service_point.photos.sorted.map do |photo|
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
      
      # POST /api/v1/clients/:client_id/favorite_points
      # Добавление сервисной точки в избранное
      def create
        # Доступно для всех авторизованных пользователей
        return render json: { error: 'Unauthorized' }, status: 401 unless current_user
        
        service_point = ServicePoint.find(params[:service_point_id])
        
        # Проверяем, что точка доступна для бронирования
        unless service_point.can_accept_bookings?
          return render json: { 
            error: 'Данная сервисная точка недоступна для добавления в избранное',
            reason: service_point.display_status
          }, status: :unprocessable_entity
        end
        
        # Проверяем, не добавлена ли уже точка в избранное
        if @client.favorite_service_points.exists?(service_point.id)
          return render json: { 
            error: 'Данная сервисная точка уже добавлена в избранное'
          }, status: :unprocessable_entity
        end
        
        @favorite_point = @client.favorite_points.build(service_point: service_point)
        
        if @favorite_point.save
          # Логируем действие
          Rails.logger.info "Клиент #{@client.id} добавил сервисную точку #{service_point.id} в избранное"
          
          render json: {
            id: @favorite_point.id,
            service_point: {
              id: service_point.id,
              name: service_point.name,
              address: service_point.address,
              city: service_point.city.name
            },
            added_at: @favorite_point.created_at,
            message: 'Сервисная точка успешно добавлена в избранное'
          }, status: :created
        else
          render json: { 
            errors: @favorite_point.errors,
            message: 'Не удалось добавить сервисную точку в избранное'
          }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/clients/:client_id/favorite_points/:id
      # Удаление сервисной точки из избранного
      def destroy
        # Доступно для всех авторизованных пользователей
        return render json: { error: 'Unauthorized' }, status: 401 unless current_user
        
        service_point_name = @favorite_point.service_point.name
        
        if @favorite_point.destroy
          Rails.logger.info "Клиент #{@client.id} удалил сервисную точку #{@favorite_point.service_point_id} из избранного"
          
          render json: { 
            message: "#{service_point_name} удалена из избранного"
          }
        else
          render json: { 
            errors: @favorite_point.errors,
            message: 'Не удалось удалить сервисную точку из избранного'
          }, status: :unprocessable_entity
        end
      end
      
      # GET /api/v1/clients/:client_id/favorite_points/check_availability
      # Проверка доступности для быстрого бронирования
      def check_availability
        # Доступно для всех авторизованных пользователей
        return render json: { error: 'Unauthorized' }, status: 401 unless current_user
        
        category_id = params[:category_id]
        date = params[:date]
        
        return render json: { error: 'Параметры category_id и date обязательны' }, status: :bad_request unless category_id && date
        
        # Получаем любимые точки с указанной категорией услуг
        favorite_points_with_category = @client.favorite_service_points
                                              .available_for_booking
                                              .joins(:service_posts)
                                              .where(service_posts: { service_category_id: category_id, is_active: true })
                                              .includes(:city, :partner)
                                              .distinct
        
        availability_data = favorite_points_with_category.map do |service_point|
          # Здесь можно добавить реальную проверку доступности слотов через DynamicAvailabilityService
          # Пока возвращаем базовую информацию
          {
            service_point: {
              id: service_point.id,
              name: service_point.name,
              address: service_point.address,
              city: service_point.city.name,
              contact_phone: service_point.contact_phone,
              average_rating: service_point.average_rating&.round(1) || 0.0
            },
            has_availability: service_point.can_accept_bookings?, # Упрощенная проверка
            estimated_slots: service_point.posts_count * 8 # Примерное количество слотов в день
          }
        end
        
        render json: {
          date: date,
          category_id: category_id,
          available_favorite_points: availability_data,
          total_count: availability_data.count
        }
      end
      
      private
      
      def set_client
        @client = if current_user&.admin?
                    Client.find(params[:client_id])
                  else
                    # Для обычных пользователей проверяем, что они обращаются к своему профилю
                    ensure_client_profile if current_user
                    current_user&.client
                  end
        
        unless @client
          render json: { error: 'Клиент не найден или доступ запрещен' }, status: :forbidden
        end
      end
      
      def set_favorite_point
        @favorite_point = @client.favorite_points.find(params[:id])
      end
      
      # Автоматически создаем клиентский профиль для пользователей других ролей
      def ensure_client_profile
        return if current_user.client.present?
        
        Client.create!(
          user: current_user,
          preferred_notification_method: 'email',
          marketing_consent: false
        )
        
        current_user.reload
      end
    end
  end
end 