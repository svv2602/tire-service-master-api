# db/seeds/service_points_improved.rb
# Улучшенные сиды для сервисных точек с полной настройкой

puts 'Creating improved service points with schedules, posts and services...'

# Проверяем зависимости
unless Partner.exists? && City.exists? && ServiceCategory.exists? && Service.exists?
  puts "  ERROR: Required data not found. Please run these seeds first:"
  puts "  - partners.rb"
  puts "  - cities.rb (or regions_cities.rb)"
  puts "  - service_categories.rb"
  puts "  - services.rb"
  exit
end

# Получаем необходимые данные
partners = Partner.limit(3).to_a
cities = City.limit(10).to_a
service_categories = ServiceCategory.all.to_a
services = Service.all.to_a

puts "  Found: #{partners.count} partners, #{cities.count} cities, #{service_categories.count} categories, #{services.count} services"

# Стандартное расписание работы (Пн-Пт: 8:00-20:00, Сб: 9:00-18:00, Вс: выходной)
default_working_hours = {
  "monday" => { "start" => "08:00", "end" => "20:00", "is_working_day" => true },
  "tuesday" => { "start" => "08:00", "end" => "20:00", "is_working_day" => true },
  "wednesday" => { "start" => "08:00", "end" => "20:00", "is_working_day" => true },
  "thursday" => { "start" => "08:00", "end" => "20:00", "is_working_day" => true },
  "friday" => { "start" => "08:00", "end" => "20:00", "is_working_day" => true },
  "saturday" => { "start" => "09:00", "end" => "18:00", "is_working_day" => true },
  "sunday" => { "start" => "10:00", "end" => "16:00", "is_working_day" => false }
}

# Расширенное расписание (работает каждый день)
extended_working_hours = {
  "monday" => { "start" => "07:00", "end" => "21:00", "is_working_day" => true },
  "tuesday" => { "start" => "07:00", "end" => "21:00", "is_working_day" => true },
  "wednesday" => { "start" => "07:00", "end" => "21:00", "is_working_day" => true },
  "thursday" => { "start" => "07:00", "end" => "21:00", "is_working_day" => true },
  "friday" => { "start" => "07:00", "end" => "21:00", "is_working_day" => true },
  "saturday" => { "start" => "08:00", "end" => "20:00", "is_working_day" => true },
  "sunday" => { "start" => "09:00", "end" => "18:00", "is_working_day" => true }
}

# Конфигурация сервисных точек
service_points_config = [
  # Киев - 3 точки
  {
    partner: partners[0],
    name: 'ШиноСервіс Експрес на Хрещатику',
    description: 'Повний спектр послуг з шиномонтажу та балансування коліс. Сучасне обладнання та досвідчені майстри.',
    city: cities.find { |c| c.name == 'Київ' } || cities[0],
    address: 'вул. Хрещатик, 22',
    contact_phone: '+380 67 123 45 67',
    is_active: true,
    work_status: 'working',
    latitude: 50.450001,
    longitude: 30.523333,
    working_hours: extended_working_hours,
         posts_config: [
       { 
         name: "Експрес-пост", 
         post_number: 1, 
         slot_duration: 30, 
         category_ids: [6], # Техническое обслуживание
         description: "Швидкий шиномонтаж та балансування"
       },
       { 
         name: "Стандартний пост", 
         post_number: 2, 
         slot_duration: 45, 
         category_ids: [6], # Техническое обслуживание
         description: "Повний спектр послуг"
       },
       { 
         name: "VIP пост", 
         post_number: 3, 
         slot_duration: 60, 
         category_ids: [7], # Дополнительные услуги
         description: "Преміум обслуговування"
       }
     ]
  },
  {
    partner: partners[0],
    name: 'ШиноСервіс Експрес на Оболоні',
    description: 'Швидкий та якісний шиномонтаж для легкових автомобілів',
    city: cities.find { |c| c.name == 'Київ' } || cities[0],
    address: 'пр. Оболонський, 45',
    contact_phone: '+380 67 123 45 68',
    is_active: true,
    work_status: 'working',
    latitude: 50.501747,
    longitude: 30.497137,
    working_hours: default_working_hours,
         posts_config: [
       { 
         name: "Пост №1", 
         post_number: 1, 
         slot_duration: 30, 
         category_ids: [6],
         description: "Шиномонтаж та балансування"
       },
       { 
         name: "Пост №2", 
         post_number: 2, 
         slot_duration: 45, 
         category_ids: [7],
         description: "Комплексне обслуговування"
       }
     ]
  },
  {
    partner: partners[1],
    name: 'АвтоШина Плюс на Позняках',
    description: 'Сучасний шиномонтаж з новітнім обладнанням',
    city: cities.find { |c| c.name == 'Київ' } || cities[0],
    address: 'вул. Драгоманова, 17',
    contact_phone: '+380 50 987 65 45',
    is_active: true,
    work_status: 'working',
    latitude: 50.411747,
    longitude: 30.627137,
    working_hours: default_working_hours,
    posts_config: [
             { 
         name: "Універсальний пост", 
         post_number: 1, 
         slot_duration: 40, 
         category_ids: [6],
         description: "Універсальний пост для всіх типів робіт"
       }
    ]
  },
  
  # Львів - 2 точки
  {
    partner: partners[1],
    name: 'АвтоШина Плюс центр',
    description: 'Професійний шиномонтаж та зберігання шин',
    city: cities.find { |c| c.name == 'Львів' } || cities[1],
    address: 'вул. Личаківська, 45',
    contact_phone: '+380 50 987 65 43',
    is_active: true,
    work_status: 'working',
    latitude: 49.842957,
    longitude: 24.031111,
    working_hours: extended_working_hours,
         posts_config: [
       { 
         name: "Швидкий пост", 
         post_number: 1, 
         slot_duration: 25, 
         category_ids: [6],
         description: "Експрес-обслуговування"
       },
       { 
         name: "Стандартний пост", 
         post_number: 2, 
         slot_duration: 45, 
         category_ids: [6],
         description: "Стандартне обслуговування"
       },
       { 
         name: "Грузовий пост", 
         post_number: 3, 
         slot_duration: 60, 
         category_ids: [7],
         description: "Обслуговування вантажних авто"
       }
     ]
  },
  {
    partner: partners[1],
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
         category_ids: [6],
         description: "Шиномонтаж та ремонт дисків"
       },
       { 
         name: "Пост №2", 
         post_number: 2, 
         slot_duration: 40, 
         category_ids: [7],
         description: "Шиномонтаж та балансування"
       }
     ]
  },
  
  # Одеса - 2 точки
  {
    partner: partners[2] || partners[0],
    name: 'ШинМайстер Одеса Центр',
    description: 'Найкращі послуги шиномонтажу в місті',
    city: cities.find { |c| c.name == 'Одеса' } || cities[2],
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
         category_ids: [6],
         description: "Швидке обслуговування"
       },
       { 
         name: "Стандарт", 
         post_number: 2, 
         slot_duration: 40, 
         category_ids: [6],
         description: "Стандартне обслуговування"
       },
       { 
         name: "Преміум", 
         post_number: 3, 
         slot_duration: 60, 
         category_ids: [7],
         description: "Преміум обслуговування"
       }
     ]
  },
  {
    partner: partners[2] || partners[0],
    name: 'ШинМайстер Одеса Пересип',
    description: 'Швидкий шиномонтаж для всіх типів авто',
    city: cities.find { |c| c.name == 'Одеса' } || cities[2],
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
         category_ids: [6],
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
    
    service_post = ServicePost.create!(
      service_point: service_point,
      name: post_config[:name],
      post_number: post_config[:post_number],
      slot_duration: post_config[:slot_duration],
      description: post_config[:description],
      service_category_id: primary_category_id,
      is_active: true,
      has_custom_schedule: false,
      working_days: ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
    )
    
    puts "    ✅ Created post: #{service_post.name} (#{service_post.slot_duration}min, Category: #{ServiceCategory.find(primary_category_id).name})"
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