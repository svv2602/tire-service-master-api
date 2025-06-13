#!/usr/bin/env ruby
# encoding: utf-8

puts "Генерация тестовых данных для фронтенда..."

# Создаем статусы бронирований если их еще нет
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

# Создаем статусы оплаты если их еще нет
if PaymentStatus.count == 0
  puts "Создание статусов оплаты..."
  
  PaymentStatus.create!(name: 'not_paid', description: 'Не оплачено', color: '#F44336', is_active: true)
  PaymentStatus.create!(name: 'paid', description: 'Оплачено', color: '#4CAF50', is_active: true)
  PaymentStatus.create!(name: 'refunded', description: 'Возвращено', color: '#2196F3', is_active: true)
  PaymentStatus.create!(name: 'partial', description: 'Частично оплачено', color: '#FFC107', is_active: true)
  
  puts "Создано статусов оплаты: #{PaymentStatus.count}"
end

# Создаем причины отмены если их еще нет
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

# Создаем регионы и города если их еще нет
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

# Создаем статусы точек обслуживания если их еще нет
if ServicePointStatus.count == 0
  puts "Создание статусов точек обслуживания..."
  
  ServicePointStatus.create!(name: 'active', description: 'Активная точка обслуживания', is_active: true)
  ServicePointStatus.create!(name: 'temporarily_closed', description: 'Временно закрыта', is_active: true)
  ServicePointStatus.create!(name: 'closed', description: 'Закрыта', is_active: true)
  ServicePointStatus.create!(name: 'maintenance', description: 'На обслуживании', is_active: true)
  
  puts "Создано статусов точек обслуживания: #{ServicePointStatus.count}"
end

# Создаем типы автомобилей
if CarType.count == 0
  puts "Создание типов автомобилей..."
  
  CarType.create!(name: "Легковой", is_active: true)
  CarType.create!(name: "Внедорожник", is_active: true)
  CarType.create!(name: "Грузовой", is_active: true)
  CarType.create!(name: "Минивэн", is_active: true)
  
  puts "Создано типов автомобилей: #{CarType.count}"
end

# Создаем бренды и модели автомобилей
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

# Создаем категории и услуги
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

# Создаем дни недели
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

# Создаем удобства для точек обслуживания
if Amenity.count == 0
  puts "Создание удобств для точек обслуживания..."
  
  Amenity.create!(name: "Wi-Fi", icon: "wifi_icon.png")
  Amenity.create!(name: "Кофе", icon: "coffee_icon.png")
  Amenity.create!(name: "Зона ожидания", icon: "waiting_area_icon.png")
  Amenity.create!(name: "Детская площадка", icon: "playground_icon.png")
  Amenity.create!(name: "Парковка", icon: "parking_icon.png")
  
  puts "Создано удобств: #{Amenity.count}"
end

# Создаем типы уведомлений если их еще нет
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

# Генерируем клиентов через API
puts "Генерация тестовых клиентов..."
5.times do
  begin
    # Проверяем, не превышено ли максимальное количество клиентов
    if Client.count >= 15
      puts "Достигнуто максимальное количество клиентов (15)"
      break
    end
    
    # Создаем уникальный email для клиента
    random_suffix = SecureRandom.hex(4)
    test_email = "test_client_#{random_suffix}@example.com"
    
    # Проверяем, существует ли уже пользователь с таким email
    if User.exists?(email: test_email)
      puts "Пропускаем создание клиента с email #{test_email} (уже существует)"
      next
    end
    
    Api::V1::Tests::DataGeneratorController.new.create_test_client_internal(test_email)
    print "."
  rescue => e
    puts "Ошибка при создании клиента: #{e.message}"
  end
end
puts "\nСоздано клиентов: #{Client.count}"

# Генерируем партнеров через API
puts "Генерация тестовых партнеров..."
3.times do
  begin
    # Проверяем, не превышено ли максимальное количество партнеров
    if Partner.count >= 5
      puts "Достигнуто максимальное количество партнеров (5)"
      break
    end
    
    # Создаем уникальный email и название компании для партнера
    random_suffix = SecureRandom.hex(4)
    test_email = "test_partner_#{random_suffix}@example.com"
    company_name = "Тестовая компания #{random_suffix}"
    
    # Проверяем, существует ли уже пользователь с таким email
    if User.exists?(email: test_email)
      puts "Пропускаем создание партнера с email #{test_email} (уже существует)"
      next
    end
    
    Api::V1::Tests::DataGeneratorController.new.create_test_partner_internal(test_email, company_name)
    print "."
  rescue => e
    puts "Ошибка при создании партнера: #{e.message}"
  end
end
puts "\nСоздано партнеров: #{Partner.count}"

# Генерируем сервисные точки для каждого партнера
puts "Генерация тестовых сервисных точек..."
Partner.all.each do |partner|
  begin
    2.times do
      Api::V1::Tests::DataGeneratorController.new.create_test_service_point_internal(partner.id)
      print "."
    end
  rescue => e
    puts "Ошибка при создании сервисной точки: #{e.message}"
  end
end
puts "\nСоздано сервисных точек: #{ServicePoint.count}"

# Генерируем менеджеров для каждого партнера
puts "Генерация тестовых менеджеров..."
Partner.all.each do |partner|
  service_points = partner.service_points
  if service_points.any?
    begin
      # Проверяем, не превышено ли максимальное количество менеджеров для этого партнера
      if Manager.where(partner_id: partner.id).count >= 2
        puts "Пропускаем создание менеджера для партнера #{partner.company_name} (уже достаточно)"
        next
      end
      
      # Создаем уникальный email для менеджера
      random_suffix = SecureRandom.hex(4)
      # Заменяем parameterize на преобразование имени компании в безопасный домен
      company_domain = partner.company_name.downcase.gsub(/[^a-z0-9]/, '').presence || "company#{random_suffix}"
      test_email = "test_manager_#{random_suffix}@#{company_domain}.com"
      
      # Проверяем, существует ли уже пользователь с таким email
      if User.exists?(email: test_email)
        puts "Пропускаем создание менеджера с email #{test_email} (уже существует)"
        next
      end
      
      Api::V1::Tests::DataGeneratorController.new.create_test_manager_internal(partner.id, service_points.first.id, test_email)
      print "."
    rescue => e
      puts "Ошибка при создании менеджера: #{e.message}"
    end
  end
end
puts "\nСоздано менеджеров: #{Manager.count}"

# Генерируем бронирования
puts "Генерация тестовых бронирований..."
Client.all.each do |client|
  ServicePoint.all.sample(2).each do |service_point|
    begin
      Api::V1::Tests::DataGeneratorController.new.create_test_booking_internal(client.id, service_point.id)
      print "."
    rescue => e
      puts "Ошибка при создании бронирования: #{e.message}"
    end
  end
end
puts "\nСоздано бронирований: #{Booking.count}"

puts "Генерация тестовых данных завершена!" 