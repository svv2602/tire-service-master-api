module Api
  module V1
    module Tests
      class DataGeneratorController < ApiController
        skip_before_action :authenticate_request
        
        # GET /api/v1/tests/generate_data
        def generate
          # Проверяем, что мы в режиме разработки
          unless Rails.env.development? || Rails.env.test?
            render json: { error: "This endpoint is only available in development or test environment" }, status: :forbidden
            return
          end
          
          ActiveRecord::Base.transaction do
            # Создаем тестового клиента
            client = create_test_client_internal
            
            # Создаем тестового партнера
            partner = create_test_partner_internal
            
            # Создаем тестовую сервисную точку для партнера
            service_point = create_test_service_point_internal(partner.id)
            
            # Создаем тестового менеджера для партнера
            manager = create_test_manager_internal(partner.id, service_point.id)
            
            # Создаем тестовое бронирование
            booking = create_test_booking_internal(client.id, service_point.id)
            
            render json: {
              message: "Test data generated successfully",
              data: {
                client: {
                  id: client.id,
                  user_id: client.user_id,
                  email: client.user.email,
                  password: "password",
                  first_name: client.user.first_name,
                  last_name: client.user.last_name
                },
                partner: {
                  id: partner.id,
                  user_id: partner.user_id,
                  email: partner.user.email,
                  password: "password",
                  company_name: partner.company_name
                },
                service_point: {
                  id: service_point.id,
                  name: service_point.name,
                  address: service_point.address
                },
                manager: {
                  id: manager.id,
                  user_id: manager.user_id,
                  email: manager.user.email,
                  password: "password",
                  first_name: manager.user.first_name,
                  last_name: manager.user.last_name
                },
                booking: {
                  id: booking.id,
                  booking_date: booking.booking_date,
                  start_time: booking.start_time,
                  end_time: booking.end_time,
                  status: BookingStatus.find(booking.status_id).name
                }
              }
            }
          end
        end
        
        # POST /api/v1/tests/create_test_client
        def create_test_client
          # Проверяем, что мы в режиме разработки
          unless Rails.env.development? || Rails.env.test?
            render json: { error: "This endpoint is only available in development or test environment" }, status: :forbidden
            return
          end
          
          client = create_test_client_internal
          
          render json: {
            message: "Test client created successfully",
            data: {
              id: client.id,
              user_id: client.user_id,
              email: client.user.email,
              password: "password",
              first_name: client.user.first_name,
              last_name: client.user.last_name
            }
          }
        end
        
        # POST /api/v1/tests/create_test_partner
        def create_test_partner
          # Проверяем, что мы в режиме разработки
          unless Rails.env.development? || Rails.env.test?
            render json: { error: "This endpoint is only available in development or test environment" }, status: :forbidden
            return
          end
          
          partner = create_test_partner_internal
          
          render json: {
            message: "Test partner created successfully",
            data: {
              id: partner.id,
              user_id: partner.user_id,
              email: partner.user.email,
              password: "password",
              company_name: partner.company_name
            }
          }
        end
        
        # POST /api/v1/tests/create_test_service_point
        def create_test_service_point
          # Проверяем, что мы в режиме разработки
          unless Rails.env.development? || Rails.env.test?
            render json: { error: "This endpoint is only available in development or test environment" }, status: :forbidden
            return
          end
          
          # Проверяем наличие partner_id
          unless params[:partner_id].present?
            render json: { error: "Partner ID is required" }, status: :bad_request
            return
          end
          
          service_point = create_test_service_point_internal(params[:partner_id])
          
          render json: {
            message: "Test service point created successfully",
            data: {
              id: service_point.id,
              name: service_point.name,
              address: service_point.address
            }
          }
        end
        
        # POST /api/v1/tests/create_test_booking
        def create_test_booking
          # Проверяем, что мы в режиме разработки
          unless Rails.env.development? || Rails.env.test?
            render json: { error: "This endpoint is only available in development or test environment" }, status: :forbidden
            return
          end
          
          # Проверяем наличие client_id и service_point_id
          unless params[:client_id].present? && params[:service_point_id].present?
            render json: { error: "Client ID and Service Point ID are required" }, status: :bad_request
            return
          end
          
          booking = create_test_booking_internal(params[:client_id], params[:service_point_id])
          
          render json: {
            message: "Test booking created successfully",
            data: {
              id: booking.id,
              booking_date: booking.booking_date,
              start_time: booking.start_time,
              end_time: booking.end_time,
              status: BookingStatus.find(booking.status_id).name
            }
          }
        end
        
        private
        
        def create_test_client_internal
          # Создаем пользователя для клиента
          user = User.create!(
            email: "test_client_#{Time.now.to_i}@example.com",
            password: "password",
            password_confirmation: "password",
            first_name: "Тестовый",
            last_name: "Клиент",
            phone: "+38067#{Random.rand(1000000..9999999)}",
            role: UserRole.find_by(name: 'client')
          )
          
          # Создаем клиента
          client = Client.create!(
            user_id: user.id,
            preferred_notification_method: "push",
            marketing_consent: true
          )
          
          # Создаем автомобиль для клиента
          # Сначала проверяем наличие необходимых объектов в базе
          car_brand = CarBrand.first || CarBrand.create!(name: "Test Brand", is_active: true)
          car_model = CarModel.first || CarModel.create!(brand_id: car_brand.id, name: "Test Model", is_active: true)
          car_type = CarType.first || CarType.create!(name: "Test Type", is_active: true)
          
          # Создаем автомобиль
          ClientCar.create!(
            client_id: client.id,
            brand_id: car_brand.id,
            model_id: car_model.id,
            car_type_id: car_type.id,
            year: 2020,
            is_primary: true
          )
          
          client
        end
        
        def create_test_partner_internal
          # Создаем пользователя для партнера
          user = User.create!(
            email: "test_partner_#{Time.now.to_i}@example.com",
            password: "password",
            password_confirmation: "password",
            first_name: "Тестовый",
            last_name: "Партнер",
            phone: "+38067#{Random.rand(1000000..9999999)}",
            role: UserRole.find_by(name: 'operator')
          )
          
          # Создаем партнера
          Partner.create!(
            user_id: user.id,
            company_name: "Тестовая компания #{Time.now.to_i}",
            company_description: "Описание тестовой компании",
            contact_person: "Тестовый Партнер",
            logo_url: "https://via.placeholder.com/150",
            website: "http://test-company.com",
            tax_number: "12345678",
            legal_address: "ул. Тестовая, 123"
          )
        end
        
        def create_test_service_point_internal(partner_id)
          # Проверяем наличие города и статуса
          city = City.first
          unless city
            region = Region.create!(name: "Test Region", is_active: true)
            city = City.create!(region_id: region.id, name: "Test City", is_active: true)
          end
          
          status = ServicePointStatus.find_by(name: 'active')
          unless status
            status = ServicePointStatus.create!(name: 'active', description: 'Active status', is_active: true)
          end
          
          # Создаем сервисную точку
          service_point = ServicePoint.create!(
            partner_id: partner_id,
            name: "Тестовая точка #{Time.now.to_i}",
            description: "Описание тестовой точки",
            address: "ул. Тестовая, 123",
            city_id: city.id,
            latitude: 50.4501,
            longitude: 30.5234,
            contact_phone: "+38067#{Random.rand(1000000..9999999)}",
            post_count: 3,
            default_slot_duration: 60,
            status_id: status.id
          )
          
          # Добавляем услуги для сервисной точки
          # Сначала проверяем наличие категории и услуг
          category = ServiceCategory.first || ServiceCategory.create!(name: "Test Category", is_active: true)
          
          # Создаем несколько тестовых услуг, если их нет
          services = Service.all
          if services.empty?
            services = []
            services << Service.create!(category_id: category.id, name: "Замена шин", default_duration: 60, is_active: true)
            services << Service.create!(category_id: category.id, name: "Балансировка", default_duration: 30, is_active: true)
            services << Service.create!(category_id: category.id, name: "Ремонт проколов", default_duration: 45, is_active: true)
          end
          
          # Связываем услуги с сервисной точкой
          services.each do |service|
            ServicePointService.create!(service_point_id: service_point.id, service_id: service.id)
          end
          
          # Создаем шаблоны расписания для всех дней недели
          weekdays = Weekday.all
          if weekdays.empty?
            weekdays = []
            day_names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
            day_names.each_with_index do |name, index|
              weekdays << Weekday.create!(name: name, day_number: index == 6 ? 0 : index + 1)
            end
          end
          
          # Для будних дней - с 9:00 до 18:00
          weekdays.each do |weekday|
            is_working = weekday.day_number != 0 && weekday.day_number != 6 # Не работаем в воскресенье (0) и субботу (6)
            
            ScheduleTemplate.create!(
              service_point_id: service_point.id,
              weekday_id: weekday.id,
              is_working_day: is_working,
              start_time: "09:00:00",
              end_time: "18:00:00"
            )
          end
          
          service_point
        end
        
        def create_test_manager_internal(partner_id, service_point_id)
          # Создаем пользователя для менеджера
          user = User.create!(
            email: "test_manager_#{Time.now.to_i}@example.com",
            password: "password",
            password_confirmation: "password",
            first_name: "Тестовый",
            last_name: "Менеджер",
            phone: "+38067#{Random.rand(1000000..9999999)}",
            role: UserRole.find_by(name: 'manager')
          )
          
          # Создаем менеджера
          manager = Manager.create!(
            user_id: user.id,
            partner_id: partner_id,
            position: "Тестовый менеджер",
            access_level: 1
          )
          
          # Связываем менеджера с сервисной точкой
          ManagerServicePoint.create!(
            manager_id: manager.id,
            service_point_id: service_point_id
          )
          
          manager
        end
        
        def create_test_booking_internal(client_id, service_point_id)
          # Находим клиента и его автомобиль
          client = Client.find(client_id)
          client_car = client.client_cars.first
          
          # Если у клиента нет автомобиля, создаем его
          unless client_car
            car_brand = CarBrand.first || CarBrand.create!(name: "Test Brand", is_active: true)
            car_model = CarModel.first || CarModel.create!(brand_id: car_brand.id, name: "Test Model", is_active: true)
            car_type = CarType.first || CarType.create!(name: "Test Type", is_active: true)
            
            client_car = ClientCar.create!(
              client_id: client.id,
              brand_id: car_brand.id,
              model_id: car_model.id,
              car_type_id: car_type.id,
              year: 2020,
              is_primary: true
            )
          end
          
          # Находим сервисную точку
          service_point = ServicePoint.find(service_point_id)
          
          # Находим или создаем слот расписания на завтра
          tomorrow = Date.tomorrow
          
          # Генерируем расписание для завтрашнего дня
          ScheduleManager.generate_slots_for_date(service_point.id, tomorrow)
          
          # Находим свободный слот
          slot = service_point.available_slots_for_date(tomorrow).first
          
          # Если нет свободных слотов, создаем новый
          unless slot
            slot = ScheduleSlot.create!(
              service_point_id: service_point.id,
              slot_date: tomorrow,
              start_time: "10:00:00",
              end_time: "11:00:00",
              post_number: 1,
              is_available: true
            )
          end
          
          # Находим или создаем статус бронирования "pending"
          pending_status = BookingStatus.find_by(name: 'pending')
          unless pending_status
            pending_status = BookingStatus.create!(
              name: 'pending',
              description: 'Ожидает подтверждения',
              color: '#FFC107',
              is_active: true
            )
          end
          
          # Находим или создаем статус оплаты "not_paid"
          not_paid_status = PaymentStatus.find_by(name: 'not_paid')
          unless not_paid_status
            not_paid_status = PaymentStatus.create!(
              name: 'not_paid',
              description: 'Не оплачено',
              color: '#F44336',
              is_active: true
            )
          end
          
          # Создаем бронирование
          booking = Booking.create!(
            client_id: client.id,
            service_point_id: service_point.id,
            car_id: client_car.id,
            car_type_id: client_car.car_type_id,
            slot_id: slot.id,
            booking_date: slot.slot_date,
            start_time: slot.start_time,
            end_time: slot.end_time,
            status_id: pending_status.id,
            payment_status_id: not_paid_status.id,
            total_price: 1000.0,
            payment_method: "cash",
            notes: "Тестовое бронирование"
          )
          
          # Добавляем услуги к бронированию
          services = service_point.services.limit(2)
          
          services.each do |service|
            BookingService.create!(
              booking_id: booking.id,
              service_id: service.id,
              price: 500.0,
              quantity: 1
            )
          end
          
          booking
        end
      end
    end
  end
end 