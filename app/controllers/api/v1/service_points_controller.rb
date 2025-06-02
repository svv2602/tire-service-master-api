module Api
  module V1
    class ServicePointsController < ApiController
      skip_before_action :authenticate_request, only: [:index, :show, :nearby, :statuses, :basic, :posts_schedule]
      before_action :set_service_point, only: [:show, :update, :destroy, :basic, :posts_schedule]
      
      # GET /api/v1/service_points
      # GET /api/v1/partners/:partner_id/service_points
      def index
        if params[:partner_id]
          @partner = Partner.find(params[:partner_id])
          @service_points = policy_scope(@partner.service_points)
        elsif params[:manager_id]
          @manager = Manager.find(params[:manager_id])
          @service_points = policy_scope(@manager.service_points)
        else
          @service_points = policy_scope(ServicePoint)
        end
        
        # Фильтрация по городу
        @service_points = @service_points.by_city(params[:city_id]) if params[:city_id].present?
        
        # Фильтрация по удобствам (amenities)
        if params[:amenity_ids].present?
          amenity_ids = params[:amenity_ids].to_s.split(',').map(&:strip)
          @service_points = @service_points.with_amenities(amenity_ids)
        end
        
        # Поиск по названию или адресу (регистронезависимый)
        if params[:query].present?
          # Используем LOWER для сравнения без учета регистра как для полей базы данных, так и для поискового запроса
          @service_points = @service_points.where("LOWER(service_points.name) LIKE LOWER(?) OR LOWER(service_points.address) LIKE LOWER(?)", 
                                              "%#{params[:query]}%", "%#{params[:query]}%")
        end
        
        # Сортировка
        if params[:sort_by] == 'rating'
          @service_points = @service_points.order(average_rating: params[:sort_direction] || 'desc')
        else
          @service_points = @service_points.order(sort_params)
        end
        
        # Возвращаем результат в формате JSON с пагинацией
        render json: paginate(@service_points)
      end
      
      # GET /api/v1/service_points/:id
      def show
        authorize @service_point
        render json: @service_point
      end
      
      # POST /api/v1/partners/:partner_id/service_points
      def create
        @partner = Partner.find(params[:partner_id])
        @service_point = @partner.service_points.new(service_point_params)
        authorize @service_point
        
        if @service_point.save
          # Обработка загруженных фотографий
          if params[:photos].present?
            params[:photos].each do |photo|
              @service_point.photos.create!(
                file: photo[:file],
                description: photo[:description],
                is_main: photo[:is_main],
                sort_order: photo[:sort_order]
              )
            end
          end
          
          log_action('create', 'service_point', @service_point.id, nil, @service_point.as_json)
          render json: @service_point, status: :created
        else
          render json: { errors: @service_point.errors }, status: :unprocessable_entity
        end
      end
      
      # PATCH/PUT /api/v1/partners/:partner_id/service_points/:id
      def update
        authorize @service_point
        
        old_values = @service_point.as_json
        
        if @service_point.update(service_point_params)
          # Обработка загруженных фотографий
          if params[:photos].present?
            # Удаляем старые фотографии, если они не используются в новом наборе
            existing_photo_ids = params[:photos].map { |p| p[:id] }.compact
            @service_point.photos.where.not(id: existing_photo_ids).destroy_all
            
            params[:photos].each do |photo|
              if photo[:id].present?
                # Обновляем существующую фотографию
                existing_photo = @service_point.photos.find(photo[:id])
                existing_photo.update!(
                  description: photo[:description],
                  is_main: photo[:is_main],
                  sort_order: photo[:sort_order]
                )
              else
                # Создаем новую фотографию
                @service_point.photos.create!(
                  file: photo[:file],
                  description: photo[:description],
                  is_main: photo[:is_main],
                  sort_order: photo[:sort_order]
                )
              end
            end
          end
          
          log_action('update', 'service_point', @service_point.id, old_values, @service_point.as_json)
          render json: @service_point
        else
          render json: { errors: @service_point.errors }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/partners/:partner_id/service_points/:id
      def destroy
        authorize @service_point
        
        old_values = @service_point.as_json
        
        if @service_point.update(status: ServicePointStatus.find_by(name: 'closed'))
          log_action('close', 'service_point', @service_point.id, old_values, @service_point.as_json)
          render json: { message: 'Service point closed successfully' }
        else
          render json: { errors: @service_point.errors }, status: :unprocessable_entity
        end
      end
      
      # GET /api/v1/service_points/nearby?latitude=XX&longitude=XX&distance=YY
      def nearby
        latitude = params[:latitude].to_f
        longitude = params[:longitude].to_f
        distance = params[:distance].to_f || 10.0 # Default 10km radius
        
        @service_points = ServicePoint.active.near(latitude, longitude, distance)
        
        render json: paginate(@service_points)
      end
      
      # GET /api/v1/service_point_statuses
      def statuses
        @statuses = ServicePointStatus.all.order(:sort_order)
        render json: @statuses
      end
      
      # GET /api/v1/service_points/:id/basic
      # Получение базовой информации о сервисной точке
      def basic
        authorize @service_point
        render json: @service_point.as_json(
          only: [:id, :name, :address, :contact_phone, :status_id],
          include: {
            city: { 
              only: [:id, :name],
              include: { region: { only: [:id, :name] } }
            },
            partner: { only: [:id, :company_name] }
          }
        )
      end
      
      # Получает расписание с детализацией по постам обслуживания
      def posts_schedule
        date = Date.parse(params[:date]) rescue Date.current
        
        schedule_by_posts = {}
        
        @service_point.service_posts.active.ordered_by_post_number.each do |service_post|
          slots = @service_point.schedule_slots
                               .where(slot_date: date, service_post: service_post)
                               .left_joins(:bookings)
                               .order(:start_time)
          
          schedule_by_posts[service_post.id] = {
            post_info: ServicePostSerializer.new(service_post).as_json,
            slots: slots.map do |slot|
              {
                id: slot.id,
                start_time: slot.start_time.strftime('%H:%M'),
                end_time: slot.end_time.strftime('%H:%M'),
                duration_minutes: slot.duration_in_minutes,
                is_available: slot.is_available,
                is_booked: slot.booked?
              }
            end,
            total_slots: slots.count,
            available_slots: slots.select { |s| s.is_available && !s.booked? }.count,
            occupancy_rate: slots.count > 0 ? ((slots.select(&:booked?).count.to_f / slots.count) * 100).round(2) : 0
          }
        end
        
        render json: {
          service_point: ServicePointBasicSerializer.new(@service_point).as_json,
          date: date,
          schedule_by_posts: schedule_by_posts,
          summary: {
            total_posts: @service_point.service_posts.active.count,
            total_slots: @service_point.schedule_slots.where(slot_date: date).count,
            total_available: @service_point.schedule_slots.where(slot_date: date, is_available: true)
                                          .left_joins(:bookings).where(bookings: { id: nil }).count
          }
        }
      end
      
      private
      
      def set_service_point
        @service_point = ServicePoint.find(params[:id])
      end
      
      def service_point_params
        params.require(:service_point).permit(
          :name,
          :description,
          :address,
          :city_id,
          :partner_id,
          :status_id,
          :phone,
          :contact_phone,
          :email,
          :latitude,
          :longitude,
          :post_count,
          :default_slot_duration,
          :working_hours,
          services_attributes: [:id, :service_id, :price, :duration, :is_available, :_destroy],
          photos_attributes: [:id, :file, :description, :is_main, :sort_order, :_destroy]
        )
      end
      
      # Метод пагинации с подключением связанных данных о городах и регионах
      # Этот метод реализует пагинацию коллекции и включает данные о городах и регионах в ответ
      # @param collection [ActiveRecord::Relation] коллекция объектов для пагинации
      # @return [Hash] хэш с данными и информацией о пагинации
      def paginate(collection)
        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 25).to_i
        offset = (page - 1) * per_page
        
        # Исправляем проблему с count, который может возвращать хэш при группировке
        total_count = collection.is_a?(ActiveRecord::Relation) ? collection.count(:all) : collection.count
        total_count = total_count.is_a?(Hash) ? total_count.values.sum : total_count
        
        # Загружаем связанные данные о городах и регионах для избежания N+1 запросов
        paginated_collection = collection.includes(city: :region).offset(offset).limit(per_page)
        
        {
          data: paginated_collection.as_json(
            include: { 
              partner: { only: [:id, :company_name] },
              # Включаем данные о городе и вложенные данные о регионе
              city: { 
                only: [:id, :name], 
                include: { region: { only: [:id, :name] } } 
              }
            }
          ),
          pagination: {
            total_count: total_count,
            total_pages: (total_count.to_f / per_page).ceil,
            current_page: page,
            per_page: per_page
          }
        }
      end
    end
  end
end
