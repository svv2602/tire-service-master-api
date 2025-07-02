module Api
  module V1
    class ClientBookingsController < ApiController
      # Пропускаем аутентификацию для клиентских записей (гостевые записи)
      # Но для create делаем опциональную аутентификацию - пытаемся аутентифицировать, но не требуем этого
      skip_before_action :authenticate_request, only: [:create, :show, :update, :cancel, :reschedule, :check_availability_for_booking]
      before_action :optional_authenticate_request, only: [:create]
      
      before_action :set_booking, only: [:show, :update, :cancel, :reschedule]
      before_action :validate_client_data, only: [:create], unless: -> { ENV['SWAGGER_DRY_RUN'] }
      
      # POST /api/v1/client_bookings
      # Создание записи клиентом (включая гостевые записи)
      def create
        # Swagger заглушка
        if ENV['SWAGGER_DRY_RUN']
          render json: build_mock_booking_response, status: :created
          return
        end
        
        # Логируем входящие параметры
        Rails.logger.info "=== CLIENT BOOKING CREATE START ==="
        Rails.logger.info "Raw params: #{params.to_unsafe_h}"
        Rails.logger.info "Current user: #{current_user&.id}"
        Rails.logger.info "Client params present: #{params[:client].present?}"
        Rails.logger.info "Booking params present: #{params[:booking].present?}"
        Rails.logger.info "Car params present: #{params[:car].present?}"
        
        # Создаем или находим клиента (может быть nil для гостевых бронирований)
        @client = find_or_create_client
        
        Rails.logger.info "Client found/created: #{@client&.id || 'GUEST_BOOKING'}"
        
        # Проверяем доступность времени
        availability_check = perform_availability_check
        unless availability_check[:available]
          Rails.logger.error "Availability check failed: #{availability_check[:reason]}"
          render json: { 
            error: 'Выбранное время недоступно', 
            reason: availability_check[:reason] 
          }, status: :unprocessable_entity
          return
        end
        
        Rails.logger.info "Availability check passed"
        
        # Создаем бронирование
        booking_result = create_client_booking
        
        Rails.logger.info "Booking creation result: #{booking_result[:success] ? 'SUCCESS' : 'FAILED'}"
        if !booking_result[:success]
          Rails.logger.error "Booking errors: #{booking_result[:errors]}"
        end
        
        if booking_result[:success]
          render json: format_booking_response(booking_result[:booking]), status: :created
        else
          render json: { 
            error: 'Не удалось создать запись', 
            details: booking_result[:errors] 
          }, status: :unprocessable_entity
        end
        
        Rails.logger.info "=== CLIENT BOOKING CREATE END ==="
      end
      
      # POST /api/v1/client_bookings/check_availability_for_booking
      # Проверка доступности перед созданием записи
      def check_availability_for_booking
        service_point_id = params[:service_point_id]
        date = params[:date]
        time = params[:time]
        duration_minutes = params[:duration_minutes].to_i || 60
        
        # Валидация параметров
        return render_validation_error('service_point_id обязателен') unless service_point_id.present?
        return render_validation_error('date обязательна') unless date.present?
        return render_validation_error('time обязательно') unless time.present?
        
        # Проверяем доступность
        availability = DynamicAvailabilityService.check_availability_at_time(
          service_point_id.to_i,
          Date.parse(date),
          Time.parse("#{date} #{time}"),
          duration_minutes
        )
        
        render json: {
          available: availability[:available],
          service_point_id: service_point_id.to_i,
          date: date,
          time: time,
          duration_minutes: duration_minutes,
          reason: availability[:reason],
          total_posts: availability[:total_posts],
          occupied_posts: availability[:occupied_posts],
          available_posts: availability[:available_posts]
        }
      end
      
      # GET /api/v1/client_bookings/:id  
      # Получение информации о записи клиента
      def show
        render json: format_booking_response(@booking)
      end
      
      # PUT /api/v1/client_bookings/:id
      # Обновление записи клиента (ограниченное)
      def update
        # Клиенты могут изменять только определенные поля до подтверждения
        unless @booking.pending?
          return render json: { 
            error: 'Запись нельзя изменить в текущем статусе',
            current_status: @booking.status.name 
          }, status: :forbidden
        end
        
        # Валидация новых данных
        if client_booking_update_params[:booking_date].present? || 
           client_booking_update_params[:start_time].present?
          
          availability = perform_availability_check_for_update
          unless availability[:available]
            return render json: { 
              error: 'Новое время недоступно', 
              reason: availability[:reason] 
            }, status: :unprocessable_entity
          end
        end
        
        if @booking.update(client_booking_update_params)
          @booking.update_total_price! if needs_price_update?
          render json: format_booking_response(@booking)
        else
          render json: { 
            error: 'Не удалось обновить запись',
            details: @booking.errors.full_messages 
          }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/client_bookings/:id
      # Отмена записи клиентом
      def cancel
        # Проверяем возможность отмены
        cancellation_check = check_cancellation_allowed
        unless cancellation_check[:allowed]
          return render json: { 
            error: 'Отмена записи не разрешена',
            reason: cancellation_check[:reason] 
          }, status: :forbidden
        end
        
        # Отменяем запись
        begin
          @booking.cancel_by_client!
          @booking.update(
            cancellation_reason_id: params[:cancellation_reason_id],
            cancellation_comment: params[:cancellation_comment]
          )
          
          render json: format_booking_response(@booking)
        rescue AASM::InvalidTransition
          render json: { 
            error: 'Невозможно отменить запись в текущем статусе',
            current_status: @booking.status.name 
          }, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/client_bookings/:id/reschedule
      # Перенос записи на другое время
      def reschedule
        new_date = params[:new_date]
        new_time = params[:new_time]
        
        # Валидация новых параметров
        return render_validation_error('new_date обязательна') unless new_date.present?
        return render_validation_error('new_time обязательно') unless new_time.present?
        
        # Проверяем доступность нового времени
        availability = DynamicAvailabilityService.check_availability_at_time(
          @booking.service_point_id,
          Date.parse(new_date),
          Time.parse("#{new_date} #{new_time}"),
          @booking.total_duration_minutes
        )
        
        unless availability[:available]
          return render json: { 
            error: 'Новое время недоступно',
            reason: availability[:reason] 
          }, status: :unprocessable_entity
        end
        
        # Переносим запись
        old_date = @booking.booking_date
        old_time = @booking.start_time
        
        if @booking.update(
          booking_date: Date.parse(new_date),
          start_time: Time.parse("#{new_date} #{new_time}"),
          end_time: Time.parse("#{new_date} #{new_time}") + @booking.total_duration_minutes.minutes
        )
          
          # Логируем изменение
          Rails.logger.info "Booking #{@booking.id} rescheduled from #{old_date} #{old_time} to #{new_date} #{new_time}"
          
          render json: format_booking_response(@booking)
        else
          render json: { 
            error: 'Не удалось перенести запись',
            details: @booking.errors.full_messages 
          }, status: :unprocessable_entity
        end
      end
      
      private
      
      def set_booking
        @booking = Booking.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Запись не найдена' }, status: :not_found
      end
      
      # Находит или создает клиента на основе переданных данных
      def find_or_create_client
        # Если передан client_id, используем его
        if params[:client_id].present?
          client = Client.find_by(id: params[:client_id])
          if client
            return client
          else
            render json: { 
              error: 'Клиент не найден',
              details: ['Указанный client_id не существует']
            }, status: :unprocessable_entity
            return nil
          end
        end

        # Если пользователь авторизован, используем его client или создаем новый
        if current_user
          if current_user.client
            Rails.logger.info("find_or_create_client: Using current_user.client (ID: #{current_user.client.id})")
            return current_user.client
          else
            # Создаем клиента для авторизованного пользователя
            Rails.logger.info("find_or_create_client: Creating new client for authenticated user (ID: #{current_user.id})")
            client = Client.create!(user: current_user)
            Rails.logger.info("find_or_create_client: Created client (ID: #{client.id}) for user (ID: #{current_user.id})")
            return client
          end
        end

        # ✅ НОВАЯ ЛОГИКА: Возвращаем nil для гостевых бронирований
        # Если нет авторизованного пользователя и client_id, создаем гостевое бронирование
        Rails.logger.info("find_or_create_client: Creating guest booking (client_id will be nil)")
        return nil
      end
      
      # Проверяет доступность времени для записи
      def perform_availability_check
        booking_data = booking_params_for_duration
        
        booking_date = booking_data[:booking_date].present? ? Date.parse(booking_data[:booking_date]) : nil
        
        DynamicAvailabilityService.check_availability_at_time(
          booking_data[:service_point_id].to_i,
          booking_date,
          Time.parse("#{booking_data[:booking_date]} #{booking_data[:start_time]}"),
          nil, # duration_minutes не передаем - сервис определит сам из category_id
          exclude_booking_id: nil,
          category_id: booking_data[:service_category_id]
        )
      end
      
      # Проверяет доступность времени для обновления
      def perform_availability_check_for_update
        update_data = client_booking_update_params
        date = update_data[:booking_date] || @booking.booking_date
        time = update_data[:start_time] || @booking.start_time
        
        DynamicAvailabilityService.check_availability_at_time(
          @booking.service_point_id,
          date,
          Time.parse("#{date} #{time}"),
          @booking.total_duration_minutes,
          exclude_booking_id: @booking.id
        )
      end
      
      # Создает услуги для бронирования
      def create_booking_services(booking)
        params[:services]&.each do |service_data|
          service = Service.find_by(id: service_data[:service_id])
          next unless service

          booking.booking_services.create!(
            service: service,
            quantity: service_data[:quantity] || 1,
            price: service_data[:price] || service.base_price
          )
        end
      rescue StandardError => e
        Rails.logger.error "Error creating booking services: #{e.message}"
      end
      
      # Создает бронирование для клиента
      def create_client_booking
        # Находим тип автомобиля
        car_type = find_or_create_car_type
        return { success: false, errors: ['Тип автомобиля не найден'] } unless car_type
        
        # Создаем бронирование (время уже рассчитано в booking_params)
        booking_data = booking_params.merge(
          client_id: @client&.id,  # ✅ Может быть nil для гостевых бронирований
          car_type_id: car_type.id,
          status_id: BookingStatus.find_by(name: 'pending')&.id
        )

        # Добавляем информацию об автомобиле в notes если она есть
        car_info = car_params
        if car_info[:license_plate].present? || car_info[:car_brand].present? || car_info[:car_model].present?
          car_notes = []
          car_notes << "Номер: #{car_info[:license_plate]}" if car_info[:license_plate].present?
          car_notes << "Марка: #{car_info[:car_brand]}" if car_info[:car_brand].present?
          car_notes << "Модель: #{car_info[:car_model]}" if car_info[:car_model].present?
          
          booking_data[:notes] = [
            booking_data[:notes],
            "Информация об автомобиле:",
            *car_notes
          ].compact.join("\n")
        end

        booking = Booking.new(booking_data)

        # Добавляем услуги если они есть
        if params[:services].present?
          create_booking_services(booking)
          booking.update_total_price!
        end

        if booking.save
          # Отправляем уведомления
          BookingNotificationJob.perform_later(booking.id, :created)
          
          # Запускаем напоминания
          BookingRemindersJob.perform_later(booking.id)
          
          { success: true, booking: booking }
        else
          { success: false, errors: booking.errors.full_messages }
        end
      rescue StandardError => e
        Rails.logger.error "Error creating booking: #{e.message}\n#{e.backtrace.join("\n")}"
        { success: false, errors: ["Внутренняя ошибка сервера: #{e.message}"] }
      end
      
      # Находит или создает тип автомобиля
      def find_or_create_car_type
        car_info = car_params
        
        # Если передан car_type_id, используем его
        if car_info[:car_type_id].present?
          car_type = CarType.find_by(id: car_info[:car_type_id])
          if car_type
            return car_type
          else
            Rails.logger.error "CarType not found with id: #{car_info[:car_type_id]}"
            render json: { 
              error: 'Тип автомобиля не найден',
              details: ['Указанный тип автомобиля не существует']
            }, status: :unprocessable_entity
            return nil
          end
        end

        # Если тип не указан, это ошибка
        render json: { 
          error: 'Тип автомобиля обязателен',
          details: ['Необходимо указать тип автомобиля']
        }, status: :unprocessable_entity
        nil
      end
      

      
      # Вспомогательный метод для получения параметров без рекурсии
      def booking_params_for_duration
        params.require(:booking).permit(
          :client_id, :service_point_id, :service_category_id, :car_type_id,
          :booking_date, :start_time, :phone, :email, :name, :car_brand, :car_model, :license_plate,
          :notes, :price
        )
      end
      
      # Проверяет возможность отмены записи
      def check_cancellation_allowed
        # Проверяем статус
        unless @booking.pending? || @booking.confirmed?
          return { allowed: false, reason: 'Запись нельзя отменить в текущем статусе' }
        end
        
        # Проверяем временные ограничения (за 2 часа до записи)
        booking_datetime = Time.parse("#{@booking.booking_date} #{@booking.start_time}")
        min_cancellation_time = booking_datetime - 2.hours
        
        if Time.current > min_cancellation_time
          return { allowed: false, reason: 'Отмена записи возможна не позднее чем за 2 часа до начала' }
        end
        
        { allowed: true }
      end
      
      # Форматирует ответ с данными бронирования
      def format_booking_response(booking)
        # Определяем данные автомобиля
        car_info = if booking.car_id.present?
          # Если есть связанный автомобиль
          car = booking.car
          {
            license_plate: car.license_plate,
            brand: car.brand&.name,
            model: car.model&.name,
            type: booking.car_type.name
          }
        else
          # Используем данные из параметров если доступны или базовую информацию
          {
            license_plate: params.dig(:car, :license_plate) || 'Не указан',
            brand: params.dig(:car, :car_brand) || 'Не указана',
            model: params.dig(:car, :car_model) || 'Не указана',
            type: booking.car_type.name
          }
        end
        
        {
          id: booking.id,
          booking_date: booking.booking_date,
          start_time: booking.start_time.strftime('%H:%M'),
          end_time: booking.end_time.strftime('%H:%M'),
          status: {
            id: booking.status_id,
            name: booking.status.name,
            display_name: booking.status.description
          },
          service_point: {
            id: booking.service_point.id,
            name: booking.service_point.name,
            address: booking.service_point.address,
            phone: booking.service_point.contact_phone
          },
          client: booking.client_booking? ? {
            name: "#{booking.client.user.first_name} #{booking.client.user.last_name}",
            phone: booking.client.user.phone,
            email: booking.client.user.email
          } : nil,
          service_recipient: {
            first_name: booking.service_recipient_first_name,
            last_name: booking.service_recipient_last_name,
            full_name: booking.service_recipient_full_name,
            phone: booking.service_recipient_phone,
            email: booking.service_recipient_email,
            is_self_service: booking.client_booking? ? booking.self_service? : true
          },
          car_info: car_info,
          services: booking.booking_services.includes(:service).map do |bs|
            {
              id: bs.service.id,
              name: bs.service.name,
              quantity: bs.quantity,
              price: bs.price
            }
          end,
          total_price: booking.total_price,
          notes: booking.notes,
          created_at: booking.created_at,
          updated_at: booking.updated_at
        }
      end
      
      # Параметры клиента
      def client_params
        params.require(:client).permit(
          :first_name,
          :last_name,
          :phone,
          :email
        )
      end
      
      # Параметры автомобиля  
      def car_params
        params.require(:car).permit(
          :license_plate,
          :car_brand,
          :car_model,
          :car_type_id
        )
      end
      
      # Параметры для создания бронирования
      def booking_params
        booking_data = booking_params_for_duration
        
        # При бронировании фиксируем только временной слот (start_time)
        # end_time остается NULL, так как не знаем какой конкретный пост будет назначен
        booking_data.merge(
          status: BookingStatus::PENDING,
          # end_time намеренно не устанавливаем - он будет NULL
        )
      end
      
      # Параметры для обновления бронирования
      def client_booking_update_params
        params.require(:booking).permit(
          :booking_date,
          :start_time,
          :end_time,
          :notes
        )
      end
      
      # Валидация данных клиента
      def validate_client_data
        # Пропускаем валидацию если передан client_id
        return if params[:client_id].present?
        
        # Пропускаем валидацию если пользователь авторизован и у него есть связанный клиент
        if current_user&.client
          Rails.logger.info("validate_client_data: Skipping validation - user has associated client (ID: #{current_user.client.id})")
          return
        end
        
        # Если пользователь авторизован, но у него нет связанного клиента, создаем его
        if current_user && !current_user.client
          Rails.logger.info("validate_client_data: Creating client for authenticated user (ID: #{current_user.id})")
          return
        end
        
        # ✅ Для гостевых бронирований валидируем только обязательные поля получателя услуги
        booking_data = params[:booking]
        unless booking_data
          render json: { 
            error: 'Данные бронирования обязательны',
            details: ['Необходимо указать данные бронирования']
          }, status: :unprocessable_entity
          return
        end

        # ✅ Проверяем обязательные поля получателя услуги для гостевых бронирований
        required_fields = []
        required_fields << 'service_recipient_first_name' if booking_data[:service_recipient_first_name].blank?
        required_fields << 'service_recipient_last_name' if booking_data[:service_recipient_last_name].blank?
        required_fields << 'service_recipient_phone' if booking_data[:service_recipient_phone].blank?
        
        # Проверяем формат телефона
        if booking_data[:service_recipient_phone].present?
          phone = booking_data[:service_recipient_phone].gsub(/[^\d+]/, '')
          unless phone.match?(/\A\+38\d{10}\z/)
            required_fields << 'phone_format'
          end
        end
        
        # Проверяем формат email если он указан
        if booking_data[:service_recipient_email].present?
          unless booking_data[:service_recipient_email].match?(URI::MailTo::EMAIL_REGEXP)
            required_fields << 'email_format'
          end
        end
        
        # Проверяем длину имени
        if booking_data[:service_recipient_first_name].present? && booking_data[:service_recipient_first_name].length < 2
          required_fields << 'first_name_length'
        end
        
        # Проверяем длину фамилии
        if booking_data[:service_recipient_last_name].present? && booking_data[:service_recipient_last_name].length < 2
          required_fields << 'last_name_length'
        end
        
        if required_fields.any?
          error_messages = {
            'service_recipient_first_name' => 'Имя получателя услуги обязательно для заполнения',
            'service_recipient_last_name' => 'Фамилия получателя услуги обязательна для заполнения',
            'first_name_length' => 'Имя должно быть не менее 2 символов',
            'last_name_length' => 'Фамилия должна быть не менее 2 символов',
            'service_recipient_phone' => 'Телефон получателя услуги обязателен для заполнения',
            'phone_format' => 'Неверный формат телефона. Используйте формат +38XXXXXXXXXX',
            'email_format' => 'Неверный формат email'
          }
          
          render json: { 
            error: 'Ошибка валидации',
            details: required_fields.map { |field| error_messages[field] }.compact
          }, status: :unprocessable_entity
          return
        end
      end
      
      # Генерирует email для гостевого пользователя
      def generate_guest_email
        "guest_#{SecureRandom.hex(8)}@tire-service.local"
      end
      
      # Проверяет, нужно ли обновлять цену
      def needs_price_update?
        params[:services].present?
      end
      
      # Рендерит ошибку валидации
      def render_validation_error(message)
        render json: { error: message }, status: :bad_request
      end
      
      # Создает заглушку для Swagger
      def build_mock_booking_response
        {
          id: Time.now.to_i,
          booking_date: Date.current + 1.day,
          start_time: '10:00',
          end_time: '11:00',
          status: { id: 1, name: 'pending', display_name: 'Ожидает подтверждения' },
          service_point: {
            id: 1,
            name: 'ШиноСервис Экспресс',
            address: 'ул. Примерная, 123',
            phone: '+380 67 123 45 67'
          },
          client: {
            name: 'Иван Иванов',
            phone: '+380 67 123 45 67',
            email: 'ivan@example.com'
          },
          car_info: {
            license_plate: 'АА1234ВВ',
            brand: 'Toyota',
            model: 'Camry',
            type: 'Легковой автомобиль'
          },
          services: [],
          total_price: 0,
          notes: 'Замена летней резины',
          created_at: Time.current,
          updated_at: Time.current
        }
      end

      # Опциональная аутентификация - пытается аутентифицировать пользователя, но не требует этого
      def optional_authenticate_request
        # Сначала пробуем получить токен из cookies (приоритет)
        access_token = cookies.encrypted[:access_token]
        Rails.logger.info("Optional Auth: access_token from cookies: #{access_token.present? ? 'present' : 'nil'}")
        
        # Если нет в cookies, пробуем из заголовка Authorization
        if access_token.nil?
          header = request.headers['Authorization']
          access_token = header.split(' ').last if header
          Rails.logger.info("Optional Auth: access_token from header: #{access_token.present? ? 'present' : 'nil'}")
        end
        
        # Если токен есть, пытаемся аутентифицировать пользователя
        if access_token.present?
          begin
            decoded = Auth::JsonWebToken.decode(access_token)
            @current_user = User.find(decoded[:user_id])
            Rails.logger.info("Optional Auth: Successfully authenticated user ID: #{@current_user.id}")
          rescue => e
            Rails.logger.info("Optional Auth: Failed to authenticate: #{e.message}")
            @current_user = nil
          end
        else
          Rails.logger.info("Optional Auth: No token found, proceeding as guest")
          @current_user = nil
        end
      end
    end
  end
end 