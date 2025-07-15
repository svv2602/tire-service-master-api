# db/seeds/service_points_localized.rb
# Создание тестовых данных для сервисных точек с локализацией

puts 'Creating localized service points...'

# Проверяем, есть ли уже точки
if ServicePoint.count > 0
  puts "  Service points already exist (#{ServicePoint.count} found), updating with localization"
else
  puts "  Creating new service points with localization"
end

# Получаем партнеров и города
partners = Partner.all
cities = City.all

if partners.empty?
  puts "  No partners found, please run partners seed first"
  exit
end

if cities.empty?
  puts "  No cities found, please run cities seed first"
  exit
end

# Локализованные данные для сервисных точек
service_points_data = [
  # Київ - 3 точки
  {
    partner_id: partners[0].id,
    name: 'ШиноСервіс Експрес на Хрещатику',
    name_ru: 'ШиноСервис Экспресс на Крещатике',
    name_uk: 'ШиноСервіс Експрес на Хрещатику',
    description: 'Повний спектр послуг з шиномонтажу та балансування коліс',
    description_ru: 'Полный спектр услуг по шиномонтажу и балансировке колес',
    description_uk: 'Повний спектр послуг з шиномонтажу та балансування коліс',
    city_id: 1, # Київ
    address: 'вул. Хрещатик, 22',
    address_ru: 'ул. Крещатик, 22',
    address_uk: 'вул. Хрещатик, 22',
    contact_phone: '+380 67 123 45 67',
    is_active: true,
    work_status: 'working',
    latitude: 50.450001,
    longitude: 30.523333,
    working_hours: {
      monday: { start: '08:00', end: '18:00', is_working_day: true },
      tuesday: { start: '08:00', end: '18:00', is_working_day: true },
      wednesday: { start: '08:00', end: '18:00', is_working_day: true },
      thursday: { start: '08:00', end: '18:00', is_working_day: true },
      friday: { start: '08:00', end: '18:00', is_working_day: true },
      saturday: { start: '09:00', end: '17:00', is_working_day: true },
      sunday: { start: '00:00', end: '00:00', is_working_day: false }
    }
  },
  {
    partner_id: partners[0].id,
    name: 'ШиноСервіс Експрес на Оболоні',
    name_ru: 'ШиноСервис Экспресс на Оболони',
    name_uk: 'ШиноСервіс Експрес на Оболоні',
    description: 'Швидкий та якісний шиномонтаж для легкових автомобілів',
    description_ru: 'Быстрый и качественный шиномонтаж для легковых автомобилей',
    description_uk: 'Швидкий та якісний шиномонтаж для легкових автомобілів',
    city_id: 1, # Київ
    address: 'пр. Оболонський, 45',
    address_ru: 'пр. Оболонский, 45',
    address_uk: 'пр. Оболонський, 45',
    contact_phone: '+380 67 123 45 68',
    is_active: true,
    work_status: 'working',
    latitude: 50.501747,
    longitude: 30.497137,
    working_hours: {
      monday: { start: '08:00', end: '18:00', is_working_day: true },
      tuesday: { start: '08:00', end: '18:00', is_working_day: true },
      wednesday: { start: '08:00', end: '18:00', is_working_day: true },
      thursday: { start: '08:00', end: '18:00', is_working_day: true },
      friday: { start: '08:00', end: '18:00', is_working_day: true },
      saturday: { start: '09:00', end: '17:00', is_working_day: true },
      sunday: { start: '00:00', end: '00:00', is_working_day: false }
    }
  },
  {
    partner_id: partners[1].id,
    name: 'АвтоШина Плюс на Позняках',
    name_ru: 'АвтоШина Плюс на Позняках',
    name_uk: 'АвтоШина Плюс на Позняках',
    description: 'Сучасний шиномонтаж з новітнім обладнанням',
    description_ru: 'Современный шиномонтаж с новейшим оборудованием',
    description_uk: 'Сучасний шиномонтаж з новітнім обладнанням',
    city_id: 1, # Київ
    address: 'вул. Драгоманова, 17',
    address_ru: 'ул. Драгоманова, 17',
    address_uk: 'вул. Драгоманова, 17',
    contact_phone: '+380 50 987 65 45',
    is_active: true,
    work_status: 'working',
    latitude: 50.411747,
    longitude: 30.627137,
    working_hours: {
      monday: { start: '09:00', end: '19:00', is_working_day: true },
      tuesday: { start: '09:00', end: '19:00', is_working_day: true },
      wednesday: { start: '09:00', end: '19:00', is_working_day: true },
      thursday: { start: '09:00', end: '19:00', is_working_day: true },
      friday: { start: '09:00', end: '19:00', is_working_day: true },
      saturday: { start: '10:00', end: '18:00', is_working_day: true },
      sunday: { start: '00:00', end: '00:00', is_working_day: false }
    }
  },
  
  # Львів - 2 точки
  {
    partner_id: partners[1].id,
    name: 'АвтоШина Плюс центр',
    name_ru: 'АвтоШина Плюс центр',
    name_uk: 'АвтоШина Плюс центр',
    description: 'Професійний шиномонтаж у центрі Львова',
    description_ru: 'Профессиональный шиномонтаж в центре Львова',
    description_uk: 'Професійний шиномонтаж у центрі Львова',
    city_id: 2, # Львів
    address: 'пл. Ринок, 1',
    address_ru: 'пл. Рынок, 1',
    address_uk: 'пл. Ринок, 1',
    contact_phone: '+380 50 987 65 46',
    is_active: true,
    work_status: 'working',
    latitude: 49.841952,
    longitude: 24.031574,
    working_hours: {
      monday: { start: '08:00', end: '18:00', is_working_day: true },
      tuesday: { start: '08:00', end: '18:00', is_working_day: true },
      wednesday: { start: '08:00', end: '18:00', is_working_day: true },
      thursday: { start: '08:00', end: '18:00', is_working_day: true },
      friday: { start: '08:00', end: '18:00', is_working_day: true },
      saturday: { start: '09:00', end: '17:00', is_working_day: true },
      sunday: { start: '00:00', end: '00:00', is_working_day: false }
    }
  },
  {
    partner_id: partners[2].id,
    name: 'КолесоМайстер Львів',
    name_ru: 'КолесоМастер Львов',
    name_uk: 'КолесоМайстер Львів',
    description: 'Експертний шиномонтаж та ремонт коліс',
    description_ru: 'Экспертный шиномонтаж и ремонт колес',
    description_uk: 'Експертний шиномонтаж та ремонт коліс',
    city_id: 2, # Львів
    address: 'вул. Городоцька, 89',
    address_ru: 'ул. Городоцкая, 89',
    address_uk: 'вул. Городоцька, 89',
    contact_phone: '+380 32 456 78 90',
    is_active: true,
    work_status: 'working',
    latitude: 49.843312,
    longitude: 24.026668,
    working_hours: {
      monday: { start: '08:00', end: '18:00', is_working_day: true },
      tuesday: { start: '08:00', end: '18:00', is_working_day: true },
      wednesday: { start: '08:00', end: '18:00', is_working_day: true },
      thursday: { start: '08:00', end: '18:00', is_working_day: true },
      friday: { start: '08:00', end: '18:00', is_working_day: true },
      saturday: { start: '09:00', end: '17:00', is_working_day: true },
      sunday: { start: '00:00', end: '00:00', is_working_day: false }
    }
  },
  
  # Одеса - 2 точки
  {
    partner_id: partners[2].id,
    name: 'КолесоМайстер Одеса',
    name_ru: 'КолесоМастер Одесса',
    name_uk: 'КолесоМайстер Одеса',
    description: 'Морський шиномонтаж біля порту',
    description_ru: 'Морской шиномонтаж возле порта',
    description_uk: 'Морський шиномонтаж біля порту',
    city_id: 3, # Одеса
    address: 'вул. Дерибасівська, 15',
    address_ru: 'ул. Дерибасовская, 15',
    address_uk: 'вул. Дерибасівська, 15',
    contact_phone: '+380 48 789 01 23',
    is_active: true,
    work_status: 'working',
    latitude: 46.485500,
    longitude: 30.723600,
    working_hours: {
      monday: { start: '08:00', end: '18:00', is_working_day: true },
      tuesday: { start: '08:00', end: '18:00', is_working_day: true },
      wednesday: { start: '08:00', end: '18:00', is_working_day: true },
      thursday: { start: '08:00', end: '18:00', is_working_day: true },
      friday: { start: '08:00', end: '18:00', is_working_day: true },
      saturday: { start: '09:00', end: '17:00', is_working_day: true },
      sunday: { start: '00:00', end: '00:00', is_working_day: false }
    }
  },
  {
    partner_id: partners[3].id,
    name: 'ШвидкоШина Одеса',
    name_ru: 'БыстроШина Одесса',
    name_uk: 'ШвидкоШина Одеса',
    description: 'Швидкий шиномонтаж без черг',
    description_ru: 'Быстрый шиномонтаж без очередей',
    description_uk: 'Швидкий шиномонтаж без черг',
    city_id: 3, # Одеса
    address: 'пр. Шевченка, 33',
    address_ru: 'пр. Шевченко, 33',
    address_uk: 'пр. Шевченка, 33',
    contact_phone: '+380 48 789 01 24',
    is_active: true,
    work_status: 'temporarily_closed',
    latitude: 46.468500,
    longitude: 30.740600,
    working_hours: {
      monday: { start: '08:00', end: '18:00', is_working_day: true },
      tuesday: { start: '08:00', end: '18:00', is_working_day: true },
      wednesday: { start: '08:00', end: '18:00', is_working_day: true },
      thursday: { start: '08:00', end: '18:00', is_working_day: true },
      friday: { start: '08:00', end: '18:00', is_working_day: true },
      saturday: { start: '09:00', end: '17:00', is_working_day: true },
      sunday: { start: '00:00', end: '00:00', is_working_day: false }
    }
  },
  
  # Харків - 1 точка
  {
    partner_id: partners[3].id,
    name: 'ШвидкоШина Харків',
    name_ru: 'БыстроШина Харьков',
    name_uk: 'ШвидкоШина Харків',
    description: 'Найшвидший шиномонтаж у Харкові',
    description_ru: 'Самый быстрый шиномонтаж в Харькове',
    description_uk: 'Найшвидший шиномонтаж у Харкові',
    city_id: 4, # Харків
    address: 'вул. Сумська, 78',
    address_ru: 'ул. Сумская, 78',
    address_uk: 'вул. Сумська, 78',
    contact_phone: '+380 57 234 56 78',
    is_active: false,
    work_status: 'suspended',
    latitude: 49.988358,
    longitude: 36.232845,
    working_hours: {
      monday: { start: '08:00', end: '18:00', is_working_day: true },
      tuesday: { start: '08:00', end: '18:00', is_working_day: true },
      wednesday: { start: '08:00', end: '18:00', is_working_day: true },
      thursday: { start: '08:00', end: '18:00', is_working_day: true },
      friday: { start: '08:00', end: '18:00', is_working_day: true },
      saturday: { start: '09:00', end: '17:00', is_working_day: true },
      sunday: { start: '00:00', end: '00:00', is_working_day: false }
    }
  }
]

# Создаем или обновляем сервисные точки
service_points_data.each_with_index do |point_data, index|
  city = City.find_by(id: point_data[:city_id])
  unless city
    puts "  Warning: City with ID #{point_data[:city_id]} not found, skipping service point"
    next
  end

  partner = Partner.find_by(id: point_data[:partner_id])
  unless partner
    puts "  Warning: Partner with ID #{point_data[:partner_id]} not found, skipping service point"
    next
  end

  # Ищем существующую точку или создаем новую
  service_point = ServicePoint.find_or_initialize_by(
    partner_id: point_data[:partner_id],
    city_id: point_data[:city_id],
    address: point_data[:address]
  )
  
  # Обновляем все поля
  service_point.assign_attributes(point_data)
  
  if service_point.save
    puts "  ✓ Created/Updated: #{service_point.name} (#{city.name})"
    
    # Создаем посты обслуживания для каждой точки
    if service_point.service_posts.empty?
      # Создаем 2-3 поста для каждой точки
      posts_count = [2, 3].sample
      
      posts_count.times do |i|
        post = service_point.service_posts.create!(
          name: "Пост #{i + 1}",
          post_number: i + 1,
          slot_duration: [30, 45, 60].sample,
          is_active: true,
          service_category_id: 1 # Предполагаем, что категория с ID 1 существует
        )
        puts "    ✓ Created post: #{post.name}"
      end
    end
  else
    puts "  ✗ Failed to create/update: #{point_data[:name]} - #{service_point.errors.full_messages.join(', ')}"
  end
end

total_count = ServicePoint.count
puts "  Total service points: #{total_count}"
puts "  Active service points: #{ServicePoint.where(is_active: true).count}"
puts "  Working service points: #{ServicePoint.where(work_status: 'working').count}"
puts "  Service points with posts: #{ServicePoint.joins(:service_posts).distinct.count}"

puts 'Localized service points created successfully!' 