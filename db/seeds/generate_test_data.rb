#!/usr/bin/env ruby
# encoding: utf-8

puts "Генерация тестовых данных для БД..."

# 0. Создаем статусы бронирований
if BookingStatus.count == 0
  puts "Создание статусов бронирований..."
  
  BookingStatus.create!(name: 'pending', description: 'Ожидает подтверждения', color: '#FFC107', is_active: true)
  BookingStatus.create!(name: 'confirmed', description: 'Подтверждено', color: '#4CAF50', is_active: true)
  BookingStatus.create!(name: 'canceled_by_client', description: 'Отменено клиентом', color: '#F44336', is_active: true)
  BookingStatus.create!(name: 'canceled_by_partner', description: 'Отменено партнером', color: '#FF5722', is_active: true)
  BookingStatus.create!(name: 'completed', description: 'Завершено', color: '#2196F3', is_active: true)
  BookingStatus.create!(name: 'no_show', description: 'Клиент не пришел', color: '#9C27B0', is_active: true)
  
  puts "Создано статусов бронирований: #{BookingStatus.count}"
end

# 1. Создаем статусы оплаты
if PaymentStatus.count == 0
  puts "Создание статусов оплаты..."
  
  PaymentStatus.create!(name: 'not_paid', description: 'Не оплачено', color: '#F44336', is_active: true)
  PaymentStatus.create!(name: 'paid', description: 'Оплачено', color: '#4CAF50', is_active: true)
  PaymentStatus.create!(name: 'refunded', description: 'Возвращено', color: '#2196F3', is_active: true)
  PaymentStatus.create!(name: 'partial', description: 'Частично оплачено', color: '#FFC107', is_active: true)
  
  puts "Создано статусов оплаты: #{PaymentStatus.count}"
end

# 2. Создаем причины отмены
if CancellationReason.count == 0
  puts "Создание причин отмены..."
  
  CancellationReason.create!(name: 'Изменение расписания', is_for_client: true, is_for_partner: true, sort_order: 1)
  CancellationReason.create!(name: 'Нашли другого поставщика услуг', is_for_client: true, is_for_partner: false, sort_order: 2)
  CancellationReason.create!(name: 'Проблема с автомобилем устранена', is_for_client: true, is_for_partner: false, sort_order: 3)
  CancellationReason.create!(name: 'Погодные условия', is_for_client: true, is_for_partner: true, sort_order: 4)
  CancellationReason.create!(name: 'Чрезвычайная ситуация', is_for_client: true, is_for_partner: true, sort_order: 5)
  CancellationReason.create!(name: 'Нехватка персонала', is_for_client: false, is_for_partner: true, sort_order: 6)
  CancellationReason.create!(name: 'Неисправность оборудования', is_for_client: false, is_for_partner: true, sort_order: 7)
  CancellationReason.create!(name: 'Перебронирование', is_for_client: false, is_for_partner: true, sort_order: 8)
  CancellationReason.create!(name: 'Другое', is_for_client: true, is_for_partner: true, sort_order: 9)
  
  puts "Создано причин отмены: #{CancellationReason.count}"
end

# 3. Создаем регионы и города
if Region.count == 0
  puts "Создание регионов и городов..."
  
  # Создаем регионы
  kyiv_region = Region.create!(name: "Киевская область", is_active: true)
  odesa_region = Region.create!(name: "Одесская область", is_active: true)
  lviv_region = Region.create!(name: "Львовская область", is_active: true)
  
  # Создаем города
  City.create!(region: kyiv_region, name: "Киев", is_active: true)
  City.create!(region: kyiv_region, name: "Ирпень", is_active: true)
  City.create!(region: odesa_region, name: "Одесса", is_active: true)
  City.create!(region: lviv_region, name: "Львов", is_active: true)
  
  puts "Создано регионов: #{Region.count}, городов: #{City.count}"
end

# 4. Создаем статусы точек обслуживания
if ServicePointStatus.count == 0
  puts "Создание статусов точек обслуживания..."
  
  ServicePointStatus.create!(name: 'active', description: 'Активная точка обслуживания', is_active: true)
  ServicePointStatus.create!(name: 'temporarily_closed', description: 'Временно закрыта', is_active: true)
  ServicePointStatus.create!(name: 'closed', description: 'Закрыта', is_active: true)
  ServicePointStatus.create!(name: 'maintenance', description: 'На обслуживании', is_active: true)
  
  puts "Создано статусов точек обслуживания: #{ServicePointStatus.count}"
end

# 5. Создаем типы автомобилей
if CarType.count == 0
  puts "Создание типов автомобилей..."
  
  CarType.create!(name: "Легковой", is_active: true)
  CarType.create!(name: "Внедорожник", is_active: true)
  CarType.create!(name: "Грузовой", is_active: true)
  CarType.create!(name: "Минивэн", is_active: true)
  
  puts "Создано типов автомобилей: #{CarType.count}"
end

# 6. Создаем бренды и модели автомобилей
if CarBrand.count == 0
  puts "Создание брендов и моделей автомобилей..."
  
  # Volkswagen
  vw = CarBrand.create!(name: "Volkswagen", is_active: true)
  CarModel.create!(brand: vw, name: "Golf", is_active: true)
  CarModel.create!(brand: vw, name: "Passat", is_active: true)
  CarModel.create!(brand: vw, name: "Tiguan", is_active: true)
  
  # Toyota
  toyota = CarBrand.create!(name: "Toyota", is_active: true)
  CarModel.create!(brand: toyota, name: "Corolla", is_active: true)
  CarModel.create!(brand: toyota, name: "Camry", is_active: true)
  CarModel.create!(brand: toyota, name: "RAV4", is_active: true)
  
  # BMW
  bmw = CarBrand.create!(name: "BMW", is_active: true)
  CarModel.create!(brand: bmw, name: "3 Series", is_active: true)
  CarModel.create!(brand: bmw, name: "5 Series", is_active: true)
  CarModel.create!(brand: bmw, name: "X5", is_active: true)
  
  puts "Создано брендов: #{CarBrand.count}, моделей: #{CarModel.count}"
end

# 7. Создаем категории и услуги
if ServiceCategory.count == 0
  puts "Создание категорий и услуг..."
  
  # Категория "Шиномонтаж"
  tire_service = ServiceCategory.create!(
    name: "Шиномонтаж",
    description: "Услуги по замене и ремонту шин",
    icon_url: "tire_service_icon.png",
    is_active: true
  )
  
  # Услуги в категории "Шиномонтаж"
  Service.create!(
    category: tire_service,
    name: "Замена шин R13-R15",
    description: "Замена шин для колес радиусом R13-R15",
    default_duration: 30,
    is_active: true
  )
  
  Service.create!(
    category: tire_service,
    name: "Замена шин R16-R18",
    description: "Замена шин для колес радиусом R16-R18",
    default_duration: 40,
    is_active: true
  )
  
  Service.create!(
    category: tire_service,
    name: "Замена шин R19-R21",
    description: "Замена шин для колес радиусом R19-R21",
    default_duration: 50,
    is_active: true
  )
  
  Service.create!(
    category: tire_service,
    name: "Балансировка",
    description: "Балансировка колес",
    default_duration: 20,
    is_active: true
  )
  
  Service.create!(
    category: tire_service,
    name: "Ремонт проколов",
    description: "Ремонт проколов шин",
    default_duration: 30,
    is_active: true
  )
  
  # Категория "Диагностика"
  diagnostics = ServiceCategory.create!(
    name: "Диагностика",
    description: "Услуги по диагностике автомобиля",
    icon_url: "diagnostics_icon.png",
    is_active: true
  )
  
  # Услуги в категории "Диагностика"
  Service.create!(
    category: diagnostics,
    name: "Проверка развал-схождения",
    description: "Диагностика и проверка развал-схождения",
    default_duration: 45,
    is_active: true
  )
  
  Service.create!(
    category: diagnostics,
    name: "Компьютерная диагностика",
    description: "Компьютерная диагностика автомобиля",
    default_duration: 60,
    is_active: true
  )
  
  puts "Создано категорий: #{ServiceCategory.count}, услуг: #{Service.count}"
end

# 8. Создаем дни недели
if Weekday.count == 0
  puts "Создание дней недели..."
  
  Weekday.create!(name: "Monday", short_name: "Mon", sort_order: 1)
  Weekday.create!(name: "Tuesday", short_name: "Tue", sort_order: 2)
  Weekday.create!(name: "Wednesday", short_name: "Wed", sort_order: 3)
  Weekday.create!(name: "Thursday", short_name: "Thu", sort_order: 4)
  Weekday.create!(name: "Friday", short_name: "Fri", sort_order: 5)
  Weekday.create!(name: "Saturday", short_name: "Sat", sort_order: 6)
  Weekday.create!(name: "Sunday", short_name: "Sun", sort_order: 7)
  
  puts "Создано дней недели: #{Weekday.count}"
end

# 9. Создаем удобства для точек обслуживания
if Amenity.count == 0
  puts "Создание удобств для точек обслуживания..."
  
  Amenity.create!(name: "Wi-Fi", icon: "wifi_icon.png")
  Amenity.create!(name: "Кофе", icon: "coffee_icon.png")
  Amenity.create!(name: "Зона ожидания", icon: "waiting_area_icon.png")
  Amenity.create!(name: "Детская площадка", icon: "playground_icon.png")
  Amenity.create!(name: "Парковка", icon: "parking_icon.png")
  
  puts "Создано удобств: #{Amenity.count}"
end

# 10. Создаем типы уведомлений
if NotificationType.count == 0
  puts "Создание типов уведомлений..."
  
  NotificationType.create!(
    name: 'new_booking',
    template: 'New booking #{booking_id} created for #{service_point_name} on #{booking_date}',
    is_push: true,
    is_email: true
  )
  
  NotificationType.create!(
    name: 'booking_confirmed',
    template: 'Booking #{booking_id} for #{service_point_name} on #{booking_date} has been confirmed',
    is_push: true,
    is_email: true
  )
  
  NotificationType.create!(
    name: 'booking_cancelled',
    template: 'Booking #{booking_id} for #{service_point_name} on #{booking_date} has been cancelled',
    is_push: true,
    is_email: true
  )
  
  puts "Создано типов уведомлений: #{NotificationType.count}"
end

# 11. Создаем тестовых клиентов
if Client.count == 0
  puts "Создание тестовых клиентов..."
  
  # Находим или создаем роль клиента
  client_role = UserRole.find_by(name: 'client')
  
  # Создаем тестовых клиентов
  5.times do |i|
    user = User.create!(
      email: "client_#{i+1}@example.com",
      password: "password",
      phone: "+3806#{rand(10000000..99999999)}",
      first_name: ["Иван", "Алексей", "Петр", "Михаил", "Сергей"][i],
      last_name: ["Иванов", "Петров", "Сидоров", "Смирнов", "Козлов"][i],
      role: client_role,
      is_active: true
    )
    
    client = Client.create!(
      user: user,
      preferred_notification_method: "push",
      marketing_consent: true
    )
    
    # Создаем автомобиль для клиента
    car_type = CarType.all.sample
    car_brand = CarBrand.all.sample
    car_model = car_brand.car_models.sample
    
    ClientCar.create!(
      client: client,
      brand: car_brand,
      model: car_model,
      car_type: car_type,
      year: rand(2010..2023),
      is_primary: true
    )
    
    # Добавляем еще один автомобиль некоторым клиентам
    if i.even?
      car_brand2 = CarBrand.where.not(id: car_brand.id).sample
      car_model2 = car_brand2.car_models.sample
      
      ClientCar.create!(
        client: client,
        brand: car_brand2,
        model: car_model2,
        car_type: car_type,
        year: rand(2010..2023),
        is_primary: false
      )
    end
  end
  
  puts "Создано клиентов: #{Client.count}, автомобилей: #{ClientCar.count}"
end

# 12. Создаем тестовых партнеров с сервисными точками
if Partner.count == 0
  puts "Создание тестовых партнеров и сервисных точек..."
  
  operator_role = UserRole.find_by(name: 'operator')
  manager_role = UserRole.find_by(name: 'manager')
  active_status = ServicePointStatus.find_by(name: 'active')
  
  # Создаем 3 партнера
  3.times do |i|
    # Создаем пользователя для партнера
    user = User.create!(
      email: "partner_#{i+1}@example.com",
      password: "password",
      phone: "+3805#{rand(10000000..99999999)}",
      first_name: ["Александр", "Николай", "Владимир"][i],
      last_name: ["Белый", "Черный", "Красный"][i],
      role: operator_role,
      is_active: true
    )
    
    # Создаем партнера
    partner = Partner.create!(
      user: user,
      company_name: ["АвтоМастер", "ШиноСервис", "МастерШин"][i],
      company_description: "Компания по обслуживанию автомобилей",
      contact_person: "#{user.first_name} #{user.last_name}",
      tax_number: "#{rand(1000000..9999999)}",
      legal_address: "ул. Примерная, #{i+1}"
    )
    
    # Создаем 2 сервисные точки для каждого партнера
    cities = City.all.sample(2)
    
    cities.each_with_index do |city, j|
      service_point = ServicePoint.create!(
        partner: partner,
        name: "#{partner.company_name} #{city.name} #{j+1}",
        description: "Сервисная точка #{j+1} партнера #{partner.company_name}",
        address: "ул. #{["Центральная", "Главная"][j]}, #{rand(1..100)}",
        city: city,
        latitude: city.name == "Киев" ? 50.45 + rand(-0.1..0.1) : (city.name == "Одесса" ? 46.48 + rand(-0.1..0.1) : 49.84 + rand(-0.1..0.1)),
        longitude: city.name == "Киев" ? 30.52 + rand(-0.1..0.1) : (city.name == "Одесса" ? 30.74 + rand(-0.1..0.1) : 24.03 + rand(-0.1..0.1)),
        contact_phone: "+3809#{rand(10000000..99999999)}",
        post_count: rand(2..5),
        default_slot_duration: [30, 60, 90].sample,
        status: active_status
      )
      
      # Добавляем удобства
      Amenity.all.sample(rand(2..5)).each do |amenity|
        ServicePointAmenity.create!(
          service_point: service_point,
          amenity: amenity
        )
      end
      
      # Добавляем услуги
      Service.all.sample(rand(3..7)).each do |service|
        ServicePointService.create!(
          service_point: service_point,
          service: service
        )
      end
      
      # Создаем менеджера для сервисной точки
      manager_user = User.create!(
        email: "manager_#{partner.id}_#{j+1}@example.com",
        password: "password",
        phone: "+3807#{rand(10000000..99999999)}",
        first_name: ["Олег", "Денис", "Виктор", "Артем", "Дмитрий"].sample,
        last_name: ["Иванченко", "Петренко", "Сидоренко", "Коваленко", "Бондаренко"].sample,
        role: manager_role,
        is_active: true
      )
      
      manager = Manager.create!(
        user: manager_user,
        partner: partner,
        position: "Менеджер сервисной точки",
        access_level: 1
      )
      
      # Связываем менеджера с сервисной точкой
      ManagerServicePoint.create!(
        manager: manager,
        service_point: service_point
      )
      
      # Создаем расписание для точки
      Weekday.all.each do |weekday|
        # Сервисная точка работает с понедельника по субботу
        is_working = weekday.sort_order < 7
        
        ScheduleTemplate.create!(
          service_point: service_point,
          weekday: weekday,
          is_working_day: is_working,
          opening_time: "09:00:00",
          closing_time: "18:00:00"
        )
      end
    end
  end
  
  puts "Создано партнеров: #{Partner.count}, сервисных точек: #{ServicePoint.count}, менеджеров: #{Manager.count}"
end

# 13. Генерируем слоты расписания и создаем бронирования
if Booking.count == 0
  puts "Создание тестовых бронирований..."
  
  # Генерируем слоты расписания на ближайшие 7 дней
  start_date = Date.today
  end_date = start_date + 6.days
  
  ServicePoint.all.each do |service_point|
    ScheduleManager.generate_slots_for_period(service_point.id, start_date, end_date)
  end
  
  pending_status = BookingStatus.find_by(name: 'pending')
  confirmed_status = BookingStatus.find_by(name: 'confirmed')
  completed_status = BookingStatus.find_by(name: 'completed')
  not_paid_status = PaymentStatus.find_by(name: 'not_paid')
  paid_status = PaymentStatus.find_by(name: 'paid')
  
  # Создаем бронирования для каждого клиента
  Client.all.each do |client|
    # Каждый клиент делает 2-3 бронирования
    rand(2..3).times do
      service_point = ServicePoint.all.sample
      car = client.cars.sample
      slot_date = [Date.today, Date.today + 1.day, Date.today + 2.days].sample
      
      # Ищем свободный слот
      available_slots = service_point.available_slots_for_date(slot_date)
      
      if available_slots.any?
        slot = available_slots.sample
        
        # Определяем статус бронирования
        status = if slot_date < Date.today
                  completed_status
                elsif slot_date == Date.today
                  [pending_status, confirmed_status].sample
                else
                  [pending_status, confirmed_status].sample
                end
        
        # Определяем статус оплаты
        payment_status = status == completed_status ? paid_status : not_paid_status
        
        # Создаем бронирование
        booking = Booking.create!(
          client: client,
          service_point: service_point,
          car: car,
          car_type: car.car_type,
          slot: slot,
          booking_date: slot.slot_date,
          start_time: slot.start_time,
          end_time: slot.end_time,
          status: status,
          payment_status: payment_status,
          total_price: rand(500..2000),
          payment_method: ["cash", "card"].sample,
          notes: ["Прошу быть внимательными", "Позвоните за 30 минут", ""].sample
        )
        
        # Добавляем услуги в бронирование
        service_point_services = service_point.service_point_services.sample(rand(1..3))
        service_point_services.each do |sps|
          BookingService.create!(
            booking: booking,
            service: sps.service,
            price: sps.service.base_price,
            quantity: rand(1..4)
          )
        end
        
        # Пересчитываем общую стоимость
        total_price = booking.booking_services.sum { |bs| bs.price * bs.quantity }
        booking.update(total_price: total_price)
      end
    end
  end
  
  puts "Создано бронирований: #{Booking.count}, услуг в бронированиях: #{BookingService.count}"
end

puts "Генерация тестовых данных завершена успешно!" 