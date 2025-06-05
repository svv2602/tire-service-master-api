module Api
  module V1
    class ServicePointsController < ApiController
      skip_before_action :authenticate_request, only: [:index, :show, :nearby, :statuses, :basic, :posts_schedule, :work_statuses, :schedule_preview, :calculate_schedule_preview]
      before_action :set_service_point, except: [:index, :create, :nearby, :statuses, :work_statuses]
      
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
        authorize @service_point
        

        
        old_values = @service_point.as_json
        
        begin
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
            :has_custom_schedule,
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
          
          posts_data.each do |post_data|
            # Находим существующий пост или создаем новый
            if post_data['id'].present?
              begin
                existing_post = @service_point.service_posts.find(post_data['id'])
                temp_post = existing_post.dup
              rescue ActiveRecord::RecordNotFound
                Rails.logger.warn "Service post with ID #{post_data['id']} not found, skipping"
                next
              end
            else
              temp_post = ServicePost.new
              temp_post.service_point_id = @service_point.id
            end
            
            # Применяем изменения из формы
            post_data.each do |key, value|
              next if ['id', '_destroy'].include?(key)
              
              # Используем writer методы модели напрямую
              if temp_post.respond_to?("#{key}=")
                temp_post.send("#{key}=", value)
              end
            end
            
            # Проверяем destroy флаг
            unless post_data['_destroy'] == '1' || post_data['_destroy'] == true
              temp_posts << temp_post
            end
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
        is_working_day = working_hours && working_hours[day_key] && 
                         (working_hours[day_key]['is_working_day'] == 'true' || 
                          working_hours[day_key]['is_working_day'] == true)
        
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
        if service_post.has_custom_schedule && service_post.working_days.present?
          service_post.working_days[day_key] == true
        else
          # Используем общее расписание точки
          true # По умолчанию считаем что работает
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
