# Скрипт для загрузки тестовых данных в базу данных
puts "Начинаем загрузку тестовых данных..."

# 1. Создаем роли пользователей (если их нет)
if UserRole.count == 0
  puts "Создаем роли пользователей..."
  
  roles = [
    { name: 'admin', display_name: 'Администратор' },
    { name: 'manager', display_name: 'Менеджер' },
    { name: 'operator', display_name: 'Оператор' },
    { name: 'client', display_name: 'Клиент' }
  ]
  
  roles.each do |role|
    UserRole.create!(name: role[:name], display_name: role[:display_name])
  end
  
  puts "Создано #{UserRole.count} ролей пользователей"
end

# 2. Создаем тестовых пользователей
if User.count == 0
  puts "Создаем тестовых пользователей..."
  
  admin_role = UserRole.find_by(name: 'admin')
  client_role = UserRole.find_by(name: 'client')
  
  # Создаем администратора
  admin = User.create!(
    email: 'admin@example.com',
    password: 'password',
    phone: '+380501234567',
    first_name: 'Admin',
    last_name: 'User',
    role: admin_role,
    is_active: true
  )
  
  # Создаем тестового клиента
  test_client = User.create!(
    email: 'client@example.com',
    password: 'password',
    phone: '+380509876543',
    first_name: 'Тест',
    last_name: 'Клиентов',
    role: client_role,
    is_active: true
  )
  
  puts "Создано #{User.count} тестовых пользователей"
end

# 3. Создаем типы автомобилей
if CarType.count == 0
  puts "Создаем типы автомобилей..."
  
  car_types = [
    { name: 'Sedan', description: 'Стандартный легковой автомобиль с отдельным багажником' },
    { name: 'Hatchback', description: 'Автомобиль с задней дверью, которая открывается вверх' },
    { name: 'SUV', description: 'Спортивный внедорожник' },
    { name: 'Crossover', description: 'Кроссовер' },
    { name: 'Pickup', description: 'Пикап с открытой грузовой площадкой сзади' }
  ]
  
  car_types.each do |type|
    CarType.find_or_create_by(name: type[:name]) do |ct|
      ct.description = type[:description]
      ct.is_active = true
    end
  end
  
  puts "Создано #{CarType.count} типов автомобилей"
end

# 4. Создаем регионы и города
if Region.count == 0
  puts "Создаем регионы и города..."
  
  # Создаем регионы
  kyiv_region = Region.create!(name: 'Киевская область', code: 'KY')
  odesa_region = Region.create!(name: 'Одесская область', code: 'OD')
  
  # Создаем города
  City.create!(name: 'Киев', region: kyiv_region)
  City.create!(name: 'Бровары', region: kyiv_region)
  City.create!(name: 'Одесса', region: odesa_region)
  
  puts "Создано #{Region.count} регионов и #{City.count} городов"
end

# 5. Создаем статусы сервисных точек
if ServicePointStatus.count == 0
  puts "Создаем статусы сервисных точек..."
  
  ServicePointStatus.create!(name: 'active', display_name: 'Активный', color: '#4CAF50')
  ServicePointStatus.create!(name: 'inactive', display_name: 'Неактивный', color: '#F44336')
  ServicePointStatus.create!(name: 'maintenance', display_name: 'На обслуживании', color: '#FFC107')
  
  puts "Создано #{ServicePointStatus.count} статусов сервисных точек"
end

# 6. Создаем категории услуг и услуги
if ServiceCategory.count == 0
  puts "Создаем категории услуг и услуги..."
  
  # Категория замены шин
  tire_category = ServiceCategory.create!(
    name: 'Замена шин',
    description: 'Услуги по замене и ремонту шин',
    is_active: true
  )
  
  # Услуги в категории замены шин
  Service.create!(
    name: 'Замена шин R13-R15',
    description: 'Замена 4 шин размером от R13 до R15',
    duration_minutes: 60,
    price: 400.0,
    category: tire_category,
    is_active: true
  )
  
  Service.create!(
    name: 'Замена шин R16-R17',
    description: 'Замена 4 шин размером от R16 до R17',
    duration_minutes: 60,
    price: 500.0,
    category: tire_category,
    is_active: true
  )
  
  # Категория балансировки
  balance_category = ServiceCategory.create!(
    name: 'Балансировка',
    description: 'Услуги по балансировке колес',
    is_active: true
  )
  
  # Услуги в категории балансировки
  Service.create!(
    name: 'Балансировка R13-R15',
    description: 'Балансировка колес размером от R13 до R15',
    duration_minutes: 40,
    price: 300.0,
    category: balance_category,
    is_active: true
  )
  
  Service.create!(
    name: 'Балансировка R16-R17',
    description: 'Балансировка колес размером от R16 до R17',
    duration_minutes: 40,
    price: 350.0,
    category: balance_category,
    is_active: true
  )
  
  puts "Создано #{ServiceCategory.count} категорий услуг и #{Service.count} услуг"
end

# 7. Создаем брэнды и модели автомобилей
if CarBrand.count == 0
  puts "Создаем брэнды и модели автомобилей..."
  
  # Toyota
  toyota = CarBrand.create!(name: 'Toyota', is_active: true)
  CarModel.create!(name: 'Camry', brand: toyota, is_active: true)
  CarModel.create!(name: 'Corolla', brand: toyota, is_active: true)
  CarModel.create!(name: 'RAV4', brand: toyota, is_active: true)
  
  # BMW
  bmw = CarBrand.create!(name: 'BMW', is_active: true)
  CarModel.create!(name: '3 Series', brand: bmw, is_active: true)
  CarModel.create!(name: '5 Series', brand: bmw, is_active: true)
  CarModel.create!(name: 'X5', brand: bmw, is_active: true)
  
  puts "Создано #{CarBrand.count} брэндов и #{CarModel.count} моделей автомобилей"
end

puts "Загрузка тестовых данных успешно завершена!"
