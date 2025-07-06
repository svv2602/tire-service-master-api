# db/seeds/service_points_improved_fixed.rb
# Создание улучшенных сервисных точек с динамическими ID категорий

puts "Creating improved service points with schedules, posts and services..."

# Получаем существующие данные
partners = Partner.includes(:user).all
cities = City.includes(:region).all  
categories = ServiceCategory.all
services = Service.includes(:category).all

puts "  Found: #{partners.count} partners, #{cities.count} cities, #{categories.count} categories, #{services.count} services"

# Проверяем наличие необходимых данных
if partners.empty? || cities.empty? || categories.empty? || services.empty?
  puts "❌ Недостаточно данных для создания сервисных точек"
  puts "   Партнеры: #{partners.count}, Города: #{cities.count}, Категории: #{categories.count}, Услуги: #{services.count}"
  puts "   Запустите сначала соответствующие seeds"
  return
end

# Получаем ID категорий динамически
shino_category_id = categories.find { |c| c.name.include?('Шиномонтаж') }&.id || 1
tech_category_id = categories.find { |c| c.name.include?('Техническое') }&.id || 2
additional_category_id = categories.find { |c| c.name.include?('Дополнительные') }&.id || 3

# Стандартные рабочие часы
default_working_hours = {
  "monday" => { "start" => "09:00", "end" => "18:00", "is_working" => true },
  "tuesday" => { "start" => "09:00", "end" => "18:00", "is_working" => true },
  "wednesday" => { "start" => "09:00", "end" => "18:00", "is_working" => true },
  "thursday" => { "start" => "09:00", "end" => "18:00", "is_working" => true },
  "friday" => { "start" => "09:00", "end" => "18:00", "is_working" => true },
  "saturday" => { "start" => "10:00", "end" => "16:00", "is_working" => true },
  "sunday" => { "start" => "10:00", "end" => "14:00", "is_working" => false }
}

# Расширенные рабочие часы
extended_working_hours = {
  "monday" => { "start" => "08:00", "end" => "20:00", "is_working" => true },
  "tuesday" => { "start" => "08:00", "end" => "20:00", "is_working" => true },
  "wednesday" => { "start" => "08:00", "end" => "20:00", "is_working" => true },
  "thursday" => { "start" => "08:00", "end" => "20:00", "is_working" => true },
  "friday" => { "start" => "08:00", "end" => "20:00", "is_working" => true },
  "saturday" => { "start" => "09:00", "end" => "18:00", "is_working" => true },
  "sunday" => { "start" => "10:00", "end" => "16:00", "is_working" => true }
}

# Конфигурация сервисных точек с динамическими ID
service_points_config = [
  # Киев - 3 точки
  {
    partner: partners[0],
    name: 'ШиноСервіс Експрес на Хрещатику',
    description: 'Швидкий та якісний шиномонтаж у центрі Києва',
    city: cities.find { |c| c.name == 'Київ' } || cities.first,
    address: 'вул. Хрещатик, 22',
    contact_phone: '+380 44 555 55 55',
    is_active: true,
    work_status: 'working',
    latitude: 50.450001,
    longitude: 30.523333,
    working_hours: default_working_hours,
    posts_config: [
      { 
        name: "Легковий пост", 
        post_number: 1, 
        slot_duration: 30, 
        category_ids: [shino_category_id],
        description: "Обслуговування легкових авто"
      },
      { 
        name: "Універсальний пост", 
        post_number: 2, 
        slot_duration: 45, 
        category_ids: [tech_category_id],
        description: "Універсальне обслуговування"
      },
      { 
        name: "Грузовий пост", 
        post_number: 3, 
        slot_duration: 60, 
        category_ids: [additional_category_id],
        description: "Обслуговування вантажних авто"
      }
    ]
  },
  {
    partner: partners[0],
    name: 'ШиноСервіс Експрес на Оболоні',
    description: 'Зручний шиномонтаж на Оболоні',
    city: cities.find { |c| c.name == 'Київ' } || cities.first,
    address: 'пр. Оболонський, 15',
    contact_phone: '+380 44 555 55 56',
    is_active: true,
    work_status: 'working',
    latitude: 50.517651,
    longitude: 30.498583,
    working_hours: default_working_hours,
    posts_config: [
      { 
        name: "Пост №1", 
        post_number: 1, 
        slot_duration: 35, 
        category_ids: [shino_category_id],
        description: "Основний пост"
      },
      { 
        name: "Пост №2", 
        post_number: 2, 
        slot_duration: 40, 
        category_ids: [tech_category_id],
        description: "Додатковий пост"
      }
    ]
  },
  {
    partner: partners[1] || partners[0],
    name: 'АвтоШина Плюс на Позняках',
    description: 'Професійний шиномонтаж та ремонт коліс',
    city: cities.find { |c| c.name == 'Київ' } || cities.first,
    address: 'вул. Драгоманова, 2а',
    contact_phone: '+380 50 987 65 43',
    is_active: true,
    work_status: 'working',
    latitude: 50.396706,
    longitude: 30.636063,
    working_hours: extended_working_hours,
    posts_config: [
      { 
        name: "Швидкий пост", 
        post_number: 1, 
        slot_duration: 25, 
        category_ids: [shino_category_id],
        description: "Експрес-обслуговування"
      },
      { 
        name: "Стандартний пост", 
        post_number: 2, 
        slot_duration: 45, 
        category_ids: [shino_category_id],
        description: "Стандартне обслуговування"
      },
      { 
        name: "Преміум пост", 
        post_number: 3, 
        slot_duration: 60, 
        category_ids: [tech_category_id],
        description: "Преміум обслуговування"
      }
    ]
  },
  
  # Львів - 2 точки
  {
    partner: partners[1] || partners[0],
    name: 'АвтоШина Плюс центр',
    description: 'Центральна точка у Львові',
    city: cities.find { |c| c.name == 'Львів' } || cities[1],
    address: 'пл. Ринок, 1',
    contact_phone: '+380 32 555 55 55',
    is_active: true,
    work_status: 'working',
    latitude: 49.841952,
    longitude: 24.031563,
    working_hours: default_working_hours,
    posts_config: [
      { 
        name: "Центральний пост", 
        post_number: 1, 
        slot_duration: 40, 
        category_ids: [shino_category_id],
        description: "Центральний пост обслуговування"
      },
      { 
        name: "Експрес пост", 
        post_number: 2, 
        slot_duration: 30, 
        category_ids: [shino_category_id],
        description: "Швидке обслуговування"
      },
      { 
        name: "Грузовий пост", 
        post_number: 3, 
        slot_duration: 60, 
        category_ids: [additional_category_id],
        description: "Обслуговування вантажних авто"
      }
    ]
  },
  {
    partner: partners[1] || partners[0],
    name: 'АвтоШина Плюс на Сихові',
    description: 'Шиномонтаж та ремонт дисків',
    city: cities.find { |c| c.name == 'Львів' } || cities[1],
    address: 'пр. Червоної Калини, 35',
    contact_phone: '+380 50 987 65 44',
    is_active: true,
    work_status: 'temporarily_closed',
    latitude: 49.816721,
    longitude: 24.056284,
    working_hours: default_working_hours,
    posts_config: [
      { 
        name: "Пост №1", 
        post_number: 1, 
        slot_duration: 30, 
        category_ids: [shino_category_id],
        description: "Шиномонтаж та ремонт дисків"
      },
      { 
        name: "Пост №2", 
        post_number: 2, 
        slot_duration: 40, 
        category_ids: [tech_category_id],
        description: "Шиномонтаж та балансування"
      }
    ]
  },
  
  # Одеса - 2 точки (используем города из Киевской области, так как Одеса может отсутствовать)
  {
    partner: partners[2] || partners[0],
    name: 'ШинМайстер Одеса Центр',
    description: 'Найкращі послуги шиномонтажу в місті',
    city: cities.find { |c| c.name == 'Бориспіль' } || cities[2],
    address: 'вул. Дерибасівська, 12',
    contact_phone: '+380 63 555 55 55',
    is_active: true,
    work_status: 'working',
    latitude: 46.482526,
    longitude: 30.723309,
    working_hours: extended_working_hours,
    posts_config: [
      { 
        name: "Експрес", 
        post_number: 1, 
        slot_duration: 25, 
        category_ids: [shino_category_id],
        description: "Швидке обслуговування"
      },
      { 
        name: "Стандарт", 
        post_number: 2, 
        slot_duration: 40, 
        category_ids: [shino_category_id],
        description: "Стандартне обслуговування"
      },
      { 
        name: "Преміум", 
        post_number: 3, 
        slot_duration: 60, 
        category_ids: [tech_category_id],
        description: "Преміум обслуговування"
      }
    ]
  },
  {
    partner: partners[2] || partners[0],
    name: 'ШинМайстер Одеса Пересип',
    description: 'Швидкий шиномонтаж для всіх типів авто',
    city: cities.find { |c| c.name == 'Бориспіль' } || cities[2],
    address: 'вул. Чорноморського Козацтва, 70',
    contact_phone: '+380 63 555 55 56',
    is_active: true,
    work_status: 'working',
    latitude: 46.562526,
    longitude: 30.773309,
    working_hours: default_working_hours,
    posts_config: [
      { 
        name: "Універсальний", 
        post_number: 1, 
        slot_duration: 35, 
        category_ids: [shino_category_id],
        description: "Універсальне обслуговування"
      }
    ]
  }
]

# Создание сервисных точек
created_points = []
service_points_config.each_with_index do |config, index|
  # Проверяем, существует ли уже точка с таким названием
  if ServicePoint.exists?(name: config[:name])
    puts "  Service point '#{config[:name]}' already exists, skipping"
    next
  end
  
  # Создаем сервисную точку
  service_point = ServicePoint.create!(
    partner: config[:partner],
    name: config[:name],
    description: config[:description],
    city: config[:city],
    address: config[:address],
    contact_phone: config[:contact_phone],
    is_active: config[:is_active],
    work_status: config[:work_status],
    latitude: config[:latitude],
    longitude: config[:longitude],
    working_hours: config[:working_hours]
  )
  
  puts "  ✅ Created service point: #{service_point.name} (#{service_point.city.name})"
  created_points << { point: service_point, config: config }
end

# Создание постов для каждой точки
created_points.each do |item|
  service_point = item[:point]
  config = item[:config]
  
  puts "  Creating posts for #{service_point.name}..."
  
  config[:posts_config].each do |post_config|
    # Получаем первую доступную категорию из списка
    primary_category_id = post_config[:category_ids].first
    
    # Проверяем, что категория существует
    unless ServiceCategory.exists?(id: primary_category_id)
      puts "    ❌ Category ID #{primary_category_id} not found, using first available category"
      primary_category_id = categories.first.id
    end
    
    service_post = ServicePost.create!(
      service_point: service_point,
      name: post_config[:name],
      post_number: post_config[:post_number],
      slot_duration: post_config[:slot_duration],
      description: post_config[:description],
      service_category_id: primary_category_id,
      is_active: true,
      has_custom_schedule: false,
      working_days: {
        "monday" => true,
        "tuesday" => true,
        "wednesday" => true,
        "thursday" => true,
        "friday" => true,
        "saturday" => true,
        "sunday" => false
      }
    )
    
    category_name = ServiceCategory.find(primary_category_id).name
    puts "    ✅ Created post: #{service_post.name} (#{service_post.slot_duration}min, Category: #{category_name})"
  end
end

# Создание услуг для сервисных точек
puts "  Creating services for service points..."

ServicePoint.all.each do |service_point|
  # Получаем категории услуг, которые поддерживает эта точка
  supported_categories = service_point.service_posts.includes(:service_category).map(&:service_category).uniq
  
  puts "    Adding services for #{service_point.name} (#{supported_categories.count} categories)..."
  
  supported_categories.each do |category|
    # Получаем услуги этой категории
    category_services = services.select { |s| s.category_id == category.id }
    
    # Добавляем 2-3 услуги из каждой категории
    category_services.sample(3).each do |service|
      # Проверяем, не существует ли уже такая связь
      unless ServicePointService.exists?(service_point: service_point, service: service)
        # Генерируем случайную цену и длительность
        base_price = [200, 300, 400, 500, 600].sample
        duration = [30, 45, 60, 90].sample
        
        ServicePointService.create!(
          service_point: service_point,
          service: service,
          price: base_price,
          duration: duration,
          is_available: true
        )
        
        puts "      ✅ Added service: #{service.name} (#{base_price} грн, #{duration}min)"
      end
    end
  end
end

puts ""
puts "🎉 Successfully created improved service points!"
puts "📊 Summary:"
puts "  - Service points: #{ServicePoint.count}"
puts "  - Service posts: #{ServicePost.count}"
puts "  - Service point services: #{ServicePointService.count}"
puts ""
puts "✅ All service points now have:"
puts "  - Working hours schedule"
puts "  - Service posts with categories"
puts "  - Available services with pricing" 