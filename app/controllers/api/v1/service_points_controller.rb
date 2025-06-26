module Api
  module V1
    class ServicePointsController < ApiController
      skip_before_action :authenticate_request, only: [:index, :show, :nearby, :statuses, :basic, :posts_schedule, :work_statuses, :schedule_preview, :calculate_schedule_preview, :client_search, :client_details, :by_category, :posts_by_category]
      before_action :set_service_point, except: [:index, :create, :nearby, :statuses, :work_statuses, :client_search, :by_category]
      
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
        authorize @partner, :create_service_point?
        
        # Отладочное логирование
        Rails.logger.info "=== Параметры создания сервисной точки ==="
        Rails.logger.info "service_posts_attributes: #{params[:service_point][:service_posts_attributes]}"
        Rails.logger.info "photos_attributes: #{params[:service_point][:photos_attributes]}"
        Rails.logger.info "Все параметры service_point: #{service_point_params.inspect}"
        
        @service_point = @partner.service_points.build(service_point_params)
        
        if @service_point.save
          log_action('create', 'service_point', @service_point.id, {}, @service_point.as_json)
          render json: @service_point, status: :created
        else
          Rails.logger.error "Ошибки при сохранении сервисной точки: #{@service_point.errors.full_messages}"
          render json: { errors: @service_point.errors }, status: :unprocessable_entity
        end
      end
      
      # PATCH/PUT /api/v1/partners/:partner_id/service_points/:id
      def update
        # Отладочное логирование для проверки авторизации
        Rails.logger.info "=== Отладка авторизации для обновления сервисной точки ==="
        Rails.logger.info "Текущий пользователь: #{current_user&.email} (ID: #{current_user&.id})"
        Rails.logger.info "Роль пользователя: #{current_user&.role}"
        Rails.logger.info "Partner ID пользователя: #{current_user&.partner&.id}"
        Rails.logger.info "Сервисная точка ID: #{@service_point.id}"
        Rails.logger.info "Partner ID сервисной точки: #{@service_point.partner_id}"
        Rails.logger.info "Может ли пользователь редактировать: #{policy(@service_point).update?}"
        
        authorize @service_point
        
        old_values = @service_point.as_json
        
        begin
          # Проверяем, передаются ли данные о рабочих часах
          if params[:service_point][:working_hours].present?
            Rails.logger.info "Получены данные о рабочих часах: #{params[:service_point][:working_hours]}"
            
            # Обновляем шаблоны расписания на основе переданных рабочих часов
            update_schedule_templates_from_working_hours
          end
          
          if @service_point.update(service_point_params)
            
            # Принудительное обновление timestamp для инвалидации кеша
            @service_point.touch(:updated_at)
            
            # Если изменились посты, очищаем связанные кеши
            if service_posts_changed?
              Rails.logger.info "Service posts updated, clearing related caches"
              # Можно добавить дополнительную логику очистки кеша здесь
            end
            
            log_action('update', 'service_point', @service_point.id, old_values, @service_point.as_json)
            
            # Возвращаем обновленные данные с timestamp для кеша
            render json: @service_point.as_json.merge(
              cache_timestamp: @service_point.updated_at.to_i,
              posts_updated: service_posts_changed?
            )
          else
            Rails.logger.error "Ошибки валидации: #{@service_point.errors.full_messages}"
            render json: { errors: @service_point.errors }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error "Ошибка при обновлении сервисной точки: #{e.class}: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          render json: { error: "Internal server error: #{e.message}" }, status: :internal_server_error
        end
      end
      
      # DELETE /api/v1/partners/:partner_id/service_points/:id
      def destroy
        authorize @service_point
        
        old_values = @service_point.as_json
        
        if @service_point.update(is_active: false, work_status: 'suspended')
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
      
      # GET /api/v1/service_points/search?city=:city_name
      # Клиентский поиск сервисных точек по названию города
      def client_search
        city_name = params[:city]
        query = params[:query] # поиск по названию/адресу точки
        
        # Базовая выборка - только доступные для бронирования точки
        @service_points = ServicePoint.available_for_booking
        
        # Фильтрация по городу (поиск по названию)
        if city_name.present?
          city = City.joins(:region).where("LOWER(cities.name) LIKE LOWER(?)", "%#{city_name}%").first
          if city
            @service_points = @service_points.where(city_id: city.id)
          else
            # Если город не найден, возвращаем пустой результат
            @service_points = ServicePoint.none
          end
        end
        
        # Поиск по названию или адресу точки
        if query.present?
          @service_points = @service_points.where(
            "LOWER(service_points.name) LIKE LOWER(?) OR LOWER(service_points.address) LIKE LOWER(?)", 
            "%#{query}%", "%#{query}%"
          )
        end
        
        # Сортировка по рейтингу (лучшие сначала)
        @service_points = @service_points.includes(:city, :partner, :reviews, :photos)
                                       .order(average_rating: :desc, name: :asc)
        
        # Возвращаем данные с дополнительной информацией для клиентов
        render json: {
          data: @service_points.map do |point|
            {
              id: point.id,
              name: point.name,
              description: point.description,
              address: point.address,
              city: {
                id: point.city.id,
                name: point.city.name,
                region: point.city.region.name
              },
              partner: {
                id: point.partner.id,
                name: point.partner.company_name
              },
              contact_phone: point.contact_phone,
              average_rating: point.average_rating&.round(1) || 0.0,
              reviews_count: point.reviews.count,
              posts_count: point.posts_count,
              can_accept_bookings: point.can_accept_bookings?,
              work_status: point.display_status,
              distance: params[:latitude] && params[:longitude] ? 
                calculate_distance(params[:latitude].to_f, params[:longitude].to_f, point.latitude, point.longitude) : nil,
              # Добавляем фотографии для отображения в карточке
              photos: point.photos.sorted.map do |photo|
                {
                  id: photo.id,
                  url: photo.file.attached? ? Rails.application.routes.url_helpers.url_for(photo.file) : nil,
                  description: photo.description,
                  is_main: photo.is_main,
                  sort_order: photo.sort_order
                }
              end
            }
          end,
          total: @service_points.count,
          city_found: city_name.blank? || @service_points.any?
        }
      end
      
      # GET /api/v1/service_points/:id/client_details  
      # Детальная информация о сервисной точке для клиентов
      def client_details
        # Проверяем, что точка доступна для бронирования
        unless @service_point.can_accept_bookings?
          return render json: { 
            error: 'Сервисная точка недоступна для записи',
            reason: @service_point.display_status
          }, status: :forbidden
        end
        
        render json: {
          id: @service_point.id,
          name: @service_point.name,
          description: @service_point.description,
          address: @service_point.address,
          city: {
            id: @service_point.city.id,
            name: @service_point.city.name,
            region: @service_point.city.region.name
          },
          partner: {
            id: @service_point.partner.id,
            name: @service_point.partner.company_name
          },
          contact_phone: @service_point.contact_phone,
          latitude: @service_point.latitude,
          longitude: @service_point.longitude,
          
          # Метрики и рейтинги
          average_rating: @service_point.average_rating&.round(1) || 0.0,
          reviews_count: @service_point.reviews.count,
          total_clients_served: @service_point.total_clients_served || 0,
          
          # Информация о постах и работе
          posts_count: @service_point.posts_count,
          can_accept_bookings: @service_point.can_accept_bookings?,
          work_status: @service_point.display_status,
          is_working_today: working_today?(@service_point),
          
          # Удобства
          amenities: @service_point.amenities.map do |amenity|
            {
              id: amenity.id,
              name: amenity.name,
              icon: amenity.icon
            }
          end,
          
          # Фотографии
          photos: @service_point.photos.order(:sort_order, :created_at).map do |photo|
            {
              id: photo.id,
              url: photo.url,
              description: photo.description
            }
          end,
          
          # Услуги (базовая информация)
          services_available: @service_point.services.active.map do |service|
            {
              id: service.id,
              name: service.name,
              category: service.service_category&.name
            }
          end,
          
          # Последние отзывы (топ-3)
          recent_reviews: @service_point.reviews
                                       .includes(:client)
                                       .order(created_at: :desc)
                                       .limit(3)
                                       .map do |review|
            {
              id: review.id,
              rating: review.rating,
              comment: review.comment,
              created_at: review.created_at.strftime('%d.%m.%Y'),
              client_name: review.client&.user&.first_name || 'Анонимный'
            }
          end
        }
      end
      
      # GET /api/v1/service_point_statuses
      def statuses
        @statuses = ServicePointStatus.all.order(:sort_order)
        render json: @statuses
      end
      
      # GET /api/v1/service_points/work_statuses
      def work_statuses
        statuses = [
          { value: 'working', label: 'Работает', description: 'Точка работает в обычном режиме' },
          { value: 'temporarily_closed', label: 'Временно закрыта', description: 'Точка временно не работает' },
          { value: 'maintenance', label: 'Техобслуживание', description: 'Проводится техническое обслуживание' },
          { value: 'suspended', label: 'Приостановлена', description: 'Работа точки приостановлена' }
        ]
        render json: statuses
      end
      
      # GET /api/v1/service_points/:id/schedule_preview?date=YYYY-MM-DD
      # Предварительный просмотр слотов с учетом индивидуальных интервалов постов
      def schedule_preview
        skip_authorization
        
        date = Date.parse(params[:date]) rescue Date.current
        
        preview_data = generate_schedule_preview_data(@service_point, date)
        render json: preview_data
      end
      
      # POST /api/v1/service_points/:id/calculate_schedule_preview
      # Рассчитывает расписание с переданными данными формы БЕЗ сохранения
      def calculate_schedule_preview
        skip_authorization
        
        date = Date.parse(params[:date]) rescue Date.current
        
        # Создаем временную копию сервисной точки с новыми данными
        temp_service_point = build_temp_service_point_with_form_data
        
        # Генерируем preview с временными данными
        preview_data = generate_schedule_preview_data(temp_service_point, date)
        
        # Добавляем метаданные о том, что это предварительный расчет
        preview_data[:is_preview_calculation] = true
        preview_data[:form_data_applied] = true
        preview_data[:calculation_timestamp] = Time.current.to_i
        
        render json: preview_data
      end
      
      # GET /api/v1/service_points/:id/basic
      # Получение базовой информации о сервисной точке
      def basic
        authorize @service_point
        render json: @service_point.as_json(
          only: [:id, :name, :address, :contact_phone, :is_active, :work_status],
          include: {
            city: { 
              only: [:id, :name],
              include: { region: { only: [:id, :name] } }
            },
            partner: { only: [:id, :company_name] }
          }
        )
      end
      
      # GET /api/v1/service_points/posts_schedule?date=YYYY-MM-DD
      def posts_schedule
        date = Date.parse(params[:date]) rescue Date.current
        
        # Получаем все посты для данной сервисной точки
        posts = @service_point.service_posts.active.includes(:schedule_slots)
        
        # Получаем расписание для каждого поста на указанную дату
        posts_schedule = posts.map do |post|
          # Получаем слоты для данного поста на указанную дату
          slots = post.schedule_slots.where(slot_date: date)
                      .order(:start_time)
          
          # Проверяем доступность каждого слота (нет ли бронирований)
          available_slots = slots.select do |slot|
            # Проверяем, нет ли бронирований на этот слот
            !Booking.exists?(
              service_point: @service_point,
              booking_date: date,
              start_time: slot.start_time,
              end_time: slot.end_time
            )
          end
          
          {
            post_id: post.id,
            post_number: post.post_number,
            post_name: post.name,
            total_slots: slots.count,
            available_slots: available_slots.count,
            occupied_slots: slots.count - available_slots.count,
            slots: slots.map do |slot|
              {
                id: slot.id,
                start_time: slot.start_time.strftime('%H:%M'),
                end_time: slot.end_time.strftime('%H:%M'),
                is_available: available_slots.include?(slot),
                is_special: slot.is_special,
                special_description: slot.special_description
              }
            end
          }
        end
        
        render json: {
          service_point_id: @service_point.id,
          date: date.strftime('%Y-%m-%d'),
          posts_schedule: posts_schedule
        }
      end
      
      # GET /api/v1/service_points/by_category?category_id=1&city_id=1
      def by_category
        category_id = params[:category_id]
        city_id = params[:city_id]
        
        return render json: { error: 'Параметр category_id обязателен' }, status: :bad_request unless category_id
        
        # Сначала получаем ID сервисных точек с постами указанной категории
        service_point_ids = ServicePost.where(service_category_id: category_id, is_active: true)
                                       .joins(:service_point)
                                       .where(service_points: { is_active: true })
                                       .pluck(:service_point_id)
                                       .uniq
        
        # Фильтруем по городу если указан
        if city_id.present?
          service_point_ids = ServicePoint.where(id: service_point_ids, city_id: city_id).pluck(:id)
        end
        
        # Получаем сервисные точки по ID
        service_points = ServicePoint.where(id: service_point_ids)
                                     .includes(:city, :partner, service_posts: :service_category)
        
        # Используем базовый метод paginate из ApiController
        result = paginate(service_points)
        
        render json: result
      end
      
      # GET /api/v1/service_points/:id/posts_by_category?category_id=1
      def posts_by_category
        category_id = params[:category_id]
        
        return render json: { error: 'Параметр category_id обязателен' }, status: :bad_request unless category_id
        
        posts = @service_point.posts_for_category(category_id)
        
        render json: {
          data: posts.includes(:service_category).map { |post| ServicePostSerializer.new(post).as_json },
          category_contact: {
            phone: @service_point.contact_phone_for_category(category_id),
            email: @service_point.contact_email_for_category(category_id)
          },
          posts_count: posts.count
        }
      end
      
      # PATCH /api/v1/service_points/:id/category_contacts
      def update_category_contacts
        contacts_data = params[:category_contacts] || {}
        
        begin
          contacts_data.each do |category_id, contact_info|
            next unless contact_info.is_a?(Hash)
            
            @service_point.set_category_contact(
              category_id,
              phone: contact_info[:phone],
              email: contact_info[:email]
            )
          end
          
          if @service_point.save
            render json: { 
              success: true, 
              category_contacts: @service_point.category_contacts,
              message: 'Контакты успешно обновлены'
            }
          else
            render json: { errors: @service_point.errors }, status: :unprocessable_entity
          end
        rescue => e
          render json: { error: "Ошибка обновления контактов: #{e.message}" }, status: :internal_server_error
        end
      end
      
      private
      
      def set_service_point
        @service_point = ServicePoint.find(params[:id])
      end
      
      def service_point_params
        
        # Для FormData Rails автоматически обрабатывает nested attributes
        params.require(:service_point).permit(
          :name, :description, :address, :city_id, :partner_id, :latitude, :longitude,
          :contact_phone, :is_active, :work_status,
          working_hours: [
            :monday => [:start, :end, :is_working_day],
            :tuesday => [:start, :end, :is_working_day], 
            :wednesday => [:start, :end, :is_working_day],
            :thursday => [:start, :end, :is_working_day],
            :friday => [:start, :end, :is_working_day],
            :saturday => [:start, :end, :is_working_day],
            :sunday => [:start, :end, :is_working_day]
          ],
          service_posts_attributes: [
            :id, :name, :description, :slot_duration, :is_active, :post_number, :_destroy,
            :has_custom_schedule, :service_category_id,
            working_days: [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday],
            custom_hours: [:start, :end]
          ],
          photos_attributes: [:id, :file, :description, :is_main, :sort_order, :_destroy],
          services_attributes: [:id, :service_id, :price, :duration, :is_available, :_destroy]
        )
      end
      
      def service_posts_changed?
        # Проверяем, были ли изменения в service_posts_attributes
        params[:service_point][:service_posts_attributes].present?
      end
      
      # Создает временную копию сервисной точки с данными из формы (без сохранения в БД)
      def build_temp_service_point_with_form_data
        # Клонируем существующую сервисную точку
        temp_service_point = @service_point.dup
        temp_service_point.id = @service_point.id # Сохраняем ID для совместимости
        
        # Применяем изменения рабочих часов если есть
        if params[:service_point][:working_hours].present?
          # Конвертируем working_hours в обычный хэш чтобы избежать проблем с ActionController::Parameters
          temp_service_point.working_hours = JSON.parse(params[:service_point][:working_hours].to_json)
        else
          temp_service_point.working_hours = @service_point.working_hours
        end
        
        # Создаем временные посты с данными из формы
        temp_posts = []
        
        if params[:service_point][:service_posts_attributes].present?
          # Преобразуем параметры в простые Ruby hashes чтобы избежать проблем с ActionController::Parameters
          posts_data = JSON.parse(params[:service_point][:service_posts_attributes].to_json)
          
          Rails.logger.info "=== Building temp posts from form data ==="
          Rails.logger.info "Posts data from form: #{posts_data.inspect}"
          
          posts_data.each_with_index do |post_data, index|
            # Проверяем destroy флаг сразу
            if post_data['_destroy'] == '1' || post_data['_destroy'] == true
              Rails.logger.info "Skipping post #{index} due to destroy flag"
              next
            end
            
            # Находим существующий пост или создаем новый
            if post_data['id'].present? && post_data['id'].to_s != '' && post_data['id'].to_s != 'undefined'
              begin
                existing_post = @service_point.service_posts.find(post_data['id'])
                temp_post = existing_post.dup
                Rails.logger.info "Found existing post ID #{post_data['id']}: #{existing_post.name}"
              rescue ActiveRecord::RecordNotFound
                Rails.logger.warn "Service post with ID #{post_data['id']} not found, creating new post"
                temp_post = ServicePost.new
                temp_post.service_point_id = @service_point.id
              end
            else
              # Создаем новый пост (для новых постов из формы)
              temp_post = ServicePost.new
              temp_post.service_point_id = @service_point.id
              Rails.logger.info "Creating new post #{index} from form data"
            end
            
            # Применяем изменения из формы
            post_data.each do |key, value|
              next if ['id', '_destroy'].include?(key)
              
              # Используем writer методы модели напрямую
              if temp_post.respond_to?("#{key}=")
                temp_post.send("#{key}=", value)
              end
            end
            
            # Устанавливаем значения по умолчанию для новых постов
            temp_post.is_active = true if temp_post.is_active.nil?
            temp_post.slot_duration = 60 if temp_post.slot_duration.nil? || temp_post.slot_duration <= 0
            
            Rails.logger.info "Processed post: name=#{temp_post.name}, post_number=#{temp_post.post_number}, is_active=#{temp_post.is_active}, slot_duration=#{temp_post.slot_duration}"
            
            temp_posts << temp_post
          end
        else
          # Если нет изменений в постах, используем существующие
          temp_posts = @service_point.service_posts.active.to_a
        end
        
        # Присваиваем временные посты
        temp_service_point.define_singleton_method(:service_posts) do
          OpenStruct.new(
            active: OpenStruct.new(
              count: temp_posts.count { |p| p.is_active },
              ordered_by_post_number: temp_posts.select { |p| p.is_active }.sort_by(&:post_number)
            )
          )
        end
        
        temp_service_point
      end
      
      # Генерирует данные preview расписания для любой сервисной точки (включая временные)
      def generate_schedule_preview_data(service_point, date)
        # Используем DynamicAvailabilityService с временными данными
        available_slots = calculate_temp_available_slots(service_point, date)
        
        # Собираем все уникальные времена из доступных слотов
        all_times = available_slots.map { |slot| slot[:start_time] }.uniq.sort
        
        # Формируем результат на основе реальных временных интервалов постов
        preview_slots = []
        
        # Проверяем рабочий день
        day_key = date.strftime('%A').downcase
        working_hours = service_point.working_hours
        
        # Логирование для отладки
        Rails.logger.info "=== Schedule Preview Debug ==="
        Rails.logger.info "Date: #{date}, Day key: #{day_key}"
        Rails.logger.info "Working hours: #{working_hours}"
        Rails.logger.info "Day hours: #{working_hours&.[](day_key)}"
        
        is_working_day = working_hours && working_hours[day_key] && 
                         (working_hours[day_key]['is_working_day'] == 'true' || 
                          working_hours[day_key]['is_working_day'] == true)
        
        Rails.logger.info "Is working day: #{is_working_day}"
        
        if is_working_day && all_times.any?
          # Для каждого уникального времени создаем preview_slot
          all_times.each do |time_str|
            # Находим все слоты, которые начинаются в это время
            slots_at_time = available_slots.select { |slot| slot[:start_time] == time_str }
            
            # Подсчитываем доступность на это время
            available_posts_count = slots_at_time.length
            total_posts = service_point.service_posts.active.count
            
            preview_slots << {
              time: time_str,
              available_posts: available_posts_count,
              total_posts: total_posts,
              is_available: available_posts_count > 0,
              post_details: slots_at_time.map do |slot|
                {
                  name: slot[:post_name],
                  number: slot[:post_number],
                  duration_minutes: slot[:duration_minutes],
                  end_time: slot[:end_time]
                }
              end
            }
          end
        end
        
        {
          service_point_id: service_point.id,
          date: date,
          day_key: day_key,
          is_working_day: is_working_day,
          preview_slots: preview_slots,
          total_active_posts: service_point.service_posts.active.count,
          raw_available_slots: available_slots, # Оригинальные слоты с учетом индивидуальных интервалов
          # Данные для управления кешем на фронтенде
          cache_timestamp: (service_point.respond_to?(:updated_at) ? service_point.updated_at : Time.current).to_i,
          cache_key: "schedule_preview_#{service_point.id}_#{date}_#{Time.current.to_i}",
          posts_last_modified: Time.current.to_i
        }
      end
      
      # Рассчитывает доступные слоты для временной сервисной точки
      def calculate_temp_available_slots(service_point, date)
        available_slots = []
        
        # Определяем день недели
        day_key = date.strftime('%A').downcase
        
        # Проходим по всем активным постам временной сервисной точки
        service_point.service_posts.active.ordered_by_post_number.each do |service_post|
          # Проверяем, работает ли пост в этот день
          next unless post_working_on_day?(service_post, day_key)
          
          # Определяем время работы поста
          start_time_str = post_start_time_for_day(service_post, day_key, service_point)
          end_time_str = post_end_time_for_day(service_post, day_key, service_point)
          
          start_time = Time.parse("#{date} #{start_time_str}")
          end_time = Time.parse("#{date} #{end_time_str}")
          
          # Генерируем слоты с индивидуальной длительностью
          current_time = start_time
          while current_time + service_post.slot_duration.minutes <= end_time
            slot_end_time = current_time + service_post.slot_duration.minutes
            
            # Проверяем доступность слота (используем реальную БД для проверки бронирований)
            is_available = !DynamicAvailabilityService.is_slot_occupied?(service_point.id, service_post.id, date, current_time, slot_end_time)
            
            if is_available
              available_slots << {
                service_post_id: service_post.id,
                post_number: service_post.post_number,
                post_name: service_post.name,
                start_time: current_time.strftime('%H:%M'),
                end_time: slot_end_time.strftime('%H:%M'),
                duration_minutes: service_post.slot_duration,
                datetime: current_time
              }
            end
            
            current_time = slot_end_time
          end
        end
        
        # Сортируем по времени
        available_slots.sort_by { |slot| slot[:datetime] }
      end
      
      # Проверяет работает ли пост в указанный день (для временных постов)
      def post_working_on_day?(service_post, day_key)
        Rails.logger.info "=== Checking if post works on #{day_key} ==="
        Rails.logger.info "Post: #{service_post.name}, has_custom_schedule: #{service_post.has_custom_schedule}"
        Rails.logger.info "Working days: #{service_post.working_days}"
        
        if service_post.has_custom_schedule && service_post.working_days.present?
          # Проверяем работает ли пост в этот день согласно индивидуальному расписанию
          is_working = service_post.working_days[day_key] == true || service_post.working_days[day_key.to_s] == true
          Rails.logger.info "Custom schedule result: #{is_working}"
          is_working
        else
          # Используем общее расписание точки - проверяем, работает ли точка в этот день
          begin
            working_hours = service_post.service_point.working_hours
          rescue
            # Для временных постов service_point может быть недоступен, получаем из переданных данных
            working_hours = nil
          end
          
          Rails.logger.info "Service point working hours: #{working_hours}"
          
          if working_hours && working_hours[day_key].present?
            is_working = working_hours[day_key]['is_working_day'] == true || working_hours[day_key]['is_working_day'] == 'true'
            Rails.logger.info "General schedule result: #{is_working}"
            is_working
          else
            Rails.logger.info "No working hours data, defaulting to false"
            false # Если нет данных о расписании, считаем выходным
          end
        end
      end
      
      # Получает время начала работы поста для дня
      def post_start_time_for_day(service_post, day_key, service_point)
        if service_post.has_custom_schedule && service_post.custom_hours.present?
          service_post.custom_hours['start'] || '09:00'
        else
          # Используем общее расписание точки
          service_point.working_hours&.dig(day_key, 'start') || '09:00'
        end
      end
      
      # Получает время окончания работы поста для дня  
      def post_end_time_for_day(service_post, day_key, service_point)
        if service_post.has_custom_schedule && service_post.custom_hours.present?
          service_post.custom_hours['end'] || '18:00'
        else
          # Используем общее расписание точки
          service_point.working_hours&.dig(day_key, 'end') || '18:00'
        end
      end
      
      # Метод пагинации с подключением связанных данных о городах и регионах
      # Этот метод реализует пагинацию коллекции и включает данные о городах и регионах в ответ
      # @param collection [ActiveRecord::Relation] коллекция объектов для пагинации
      # @return [Hash] хэш с данными и информацией о пагинации
      def paginate(collection)
        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 10).to_i
        per_page = [per_page, 100].min # ограничиваем максимальным значением
        
        offset = (page - 1) * per_page
        total_count = collection.count
        
        paginated_collection = collection.offset(offset).limit(per_page)
        
        {
          data: paginated_collection.as_json(
            only: [:id, :name, :address, :latitude, :longitude, :contact_phone, :average_rating, :total_clients_served, :cancellation_rate, :post_count, :partner_id, :city_id, :is_active, :work_status, :working_hours],
            include: {
              city: { only: [:id, :name], include: { region: { only: [:id, :name] } } },
              partner: { only: [:id, :company_name] }
            }
          ),
          pagination: {
            current_page: page,
            total_pages: (total_count.to_f / per_page).ceil,
            total_count: total_count,
            per_page: per_page
          }
        }
      end
      
      # Вспомогательные методы для клиентских endpoints
      
      # Проверяет, работает ли точка сегодня
      def working_today?(service_point)
        today = Date.current
        
        # Упрощенная логика - считаем что работает пн-сб  
        !today.sunday?
      end
      
      # Расчет расстояния между двумя точками (упрощенный)
      def calculate_distance(lat1, lon1, lat2, lon2)
        return nil if lat2.nil? || lon2.nil?
        
        # Формула гаверсинуса для расчета расстояния
        earth_radius = 6371 # км
        
        dlat = (lat2 - lat1) * Math::PI / 180
        dlon = (lon2 - lon1) * Math::PI / 180
        
        a = Math.sin(dlat / 2) * Math.sin(dlat / 2) +
            Math.cos(lat1 * Math::PI / 180) * Math.cos(lat2 * Math::PI / 180) *
            Math.sin(dlon / 2) * Math.sin(dlon / 2)
        
        c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
        distance = earth_radius * c
        
        distance.round(2)
      end
      
      # Обновляет шаблоны расписания на основе переданных рабочих часов
      def update_schedule_templates_from_working_hours
        working_hours = params[:service_point][:working_hours]
        return unless working_hours.is_a?(Hash)
        
        # Маппинг дней недели
        day_to_sort_order = {
          'monday' => 1,
          'tuesday' => 2,
          'wednesday' => 3,
          'thursday' => 4,
          'friday' => 5,
          'saturday' => 6,
          'sunday' => 7
        }
        
        # Обновляем шаблоны расписания для каждого дня недели
        working_hours.each do |day_name, hours|
          sort_order = day_to_sort_order[day_name.to_s]
          next unless sort_order
          
          weekday = Weekday.find_by(sort_order: sort_order)
          next unless weekday
          
          template = @service_point.schedule_templates.find_or_initialize_by(weekday: weekday)
          
          is_working_day = hours['is_working_day'].to_s == 'true'
          
          template.is_working_day = is_working_day
          if is_working_day
            template.opening_time = hours['start']
            template.closing_time = hours['end']
          else
            template.opening_time = '00:00:00'
            template.closing_time = '00:00:00'
          end
          
          template.save
        end
        
        # Обновляем поле working_hours в модели ServicePoint
        @service_point.update_working_hours_from_templates
      end
    end
  end
end
