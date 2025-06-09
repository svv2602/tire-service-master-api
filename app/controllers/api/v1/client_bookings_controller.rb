module Api
  module V1
    class ClientBookingsController < ApiController
      # Пропускаем аутентификацию для клиентских записей (гостевые записи)
      skip_before_action :authenticate_request, only: [:create, :show, :update, :cancel, :reschedule, :check_availability_for_booking]
      
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
        
        # Создаем или находим клиента
        @client = find_or_create_client
        return unless @client
        
        # Проверяем доступность времени
        availability_check = perform_availability_check
        unless availability_check[:available]
          render json: { 
            error: 'Выбранное время недоступно', 
            reason: availability_check[:reason] 
          }, status: :unprocessable_entity
          return
        end
        
        # Создаем бронирование
        booking_result = create_client_booking
        
        if booking_result[:success]
          render json: format_booking_response(booking_result[:booking]), status: :created
        else
          render json: { 
            error: 'Не удалось создать запись', 
            details: booking_result[:errors] 
          }, status: :unprocessable_entity
        end
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
        client_data = client_params
        
        # Сначала ищем по email, если указан
        if client_data[:email].present?
          user = User.find_by(email: client_data[:email])
          return user.client if user&.client
        end
        
        # Ищем по телефону
        if client_data[:phone].present?
          user = User.find_by(phone: client_data[:phone])
          return user.client if user&.client
        end
        
        # Получаем роль клиента
        client_role = UserRole.find_by(name: 'client')
        unless client_role
          render json: { 
            error: 'Системная ошибка: роль клиента не настроена' 
          }, status: :internal_server_error
          return nil
        end
        
        # Создаем нового гостевого клиента
        user = User.create!(
          email: client_data[:email].presence || generate_guest_email,
          phone: client_data[:phone],
          first_name: client_data[:first_name],
          last_name: client_data[:last_name],
          password: SecureRandom.hex(12), # Случайный пароль для гостя
          role: client_role,
          is_active: true
        )
        
        # Client создается автоматически в коллбэке
        user.client
      rescue ActiveRecord::RecordInvalid => e
        render json: { 
          error: 'Ошибка при создании клиента',
          details: e.record.errors.full_messages 
        }, status: :unprocessable_entity
        nil
      end
      
      # Проверяет доступность времени для записи
      def perform_availability_check
        booking_data = booking_params
        
        DynamicAvailabilityService.check_availability_at_time(
          booking_data[:service_point_id].to_i,
          Date.parse(booking_data[:booking_date]),
          Time.parse("#{booking_data[:booking_date]} #{booking_data[:start_time]}"),
          calculate_duration_minutes
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
      
      # Создает бронирование для клиента
      def create_client_booking
        booking_data = booking_params.merge(client_id: @client.id)
        
        # Создаем или находим тип автомобиля
        car_type = find_or_create_car_type
        booking_data[:car_type_id] = car_type.id
        
        # Создаем автомобиль клиента если данные предоставлены
        car = create_client_car
        booking_data[:car_id] = car.id if car
        
        # Определяем время окончания
        start_datetime = Time.parse("#{booking_data[:booking_date]} #{booking_data[:start_time]}")
        end_datetime = start_datetime + calculate_duration_minutes.minutes
        booking_data[:end_time] = end_datetime.strftime('%H:%M')
        
        # Устанавливаем статус
        booking_data[:status_id] = BookingStatus.pending_id
        
        booking = Booking.new(booking_data)
        
        if booking.save
          # Добавляем услуги если указаны
          create_booking_services(booking) if params[:services].present?
          booking.update_total_price!
          
          { success: true, booking: booking }
        else
          { success: false, errors: booking.errors.full_messages }
        end
      end
      
      # Создает автомобиль для клиента
      def create_client_car
        car_info = car_params
        return nil unless car_info[:license_plate].present?
        
        # Ищем существующий автомобиль клиента по номеру
        existing_car = ClientCar.find_by(
          client_id: @client.id,
          license_plate: car_info[:license_plate]
        )
        
        return existing_car if existing_car
        
        # Находим или создаем бренды и модели
        car_brand = nil
        car_model = nil
        car_type = find_or_create_car_type
        
        if car_info[:car_brand].present?
          car_brand = CarBrand.find_or_create_by(name: car_info[:car_brand])
          
          if car_info[:car_model].present?
            car_model = CarModel.find_or_create_by(
              name: car_info[:car_model],
              brand: car_brand
            )
          end
        end
        
        # Создаем автомобиль
        ClientCar.create(
          client: @client,
          license_plate: car_info[:license_plate],
          brand: car_brand,
          model: car_model,
          car_type: car_type,
          year: car_info[:year]&.to_i,
          is_primary: false
        )
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.warn "Failed to create car: #{e.message}"
        nil
      end
      
      # Находит или создает тип автомобиля
      def find_or_create_car_type
        car_info = car_params
        
        # Ищем существующий тип по названию
        if car_info[:car_brand].present? && car_info[:car_model].present?
          car_type_name = "#{car_info[:car_brand]} #{car_info[:car_model]}"
          car_type = CarType.find_by('name ILIKE ?', car_type_name)
          return car_type if car_type
        end
        
        # Создаем новый тип на основе переданных данных или общий
        type_name = if car_info[:car_brand].present?
          "#{car_info[:car_brand]} #{car_info[:car_model].presence || 'Неизвестная модель'}"
        else
          'Легковой автомобиль'
        end
        
        CarType.find_or_create_by(name: type_name) do |ct|
          ct.description = "Автомобиль: #{type_name}"
          ct.is_active = true
        end
      end
      
      # Создает услуги для бронирования
      def create_booking_services(booking)
        params[:services]&.each do |service_data|
          next unless service_data[:service_id].present?
          
          booking.booking_services.create!(
            service_id: service_data[:service_id],
            quantity: service_data[:quantity] || 1,
            price: service_data[:price] || 0
          )
        end
      end
      
      # Рассчитывает продолжительность услуг
      def calculate_duration_minutes
        if params[:services].present?
          total_duration = params[:services].sum do |service|
            Service.find_by(id: service[:service_id])&.duration_minutes || 60
          end
          [total_duration, 60].max # Минимум 60 минут
        else
          params[:duration_minutes]&.to_i || 60
        end
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
          client: {
            name: "#{booking.client.user.first_name} #{booking.client.user.last_name}",
            phone: booking.client.user.phone,
            email: booking.client.user.email
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
          :first_name, :last_name, :phone, :email
        )
      end
      
      # Параметры автомобиля  
      def car_params
        params.permit(
          car: [:license_plate, :car_brand, :car_model, :year]
        )[:car] || {}
      end
      
      # Параметры бронирования
      def booking_params
        params.require(:booking).permit(
          :service_point_id, :booking_date, :start_time, :notes
        )
      end
      
      # Параметры для обновления бронирования
      def client_booking_update_params
        params.require(:booking).permit(
          :booking_date, :start_time, :notes
        )
      end
      
      # Валидация данных клиента
      def validate_client_data
        client_data = params[:client]
        car_data = params[:car]
        
        errors = []
        
        # Проверяем обязательные поля клиента
        errors << 'Имя клиента обязательно' unless client_data[:first_name].present?
        errors << 'Фамилия клиента обязательна' unless client_data[:last_name].present?
        errors << 'Телефон клиента обязателен' unless client_data[:phone].present?
        
        # Проверяем обязательные поля автомобиля
        errors << 'Номер автомобиля обязателен' unless car_data[:license_plate].present?
        
        if errors.any?
          render json: { 
            error: 'Данные клиента заполнены неполно',
            details: errors 
          }, status: :unprocessable_entity
          return false
        end
        
        true
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
    end
  end
end 