# db/seeds/service_points.rb
# Створення тестових даних для точок обслуговування

puts 'Creating service points...'

# Проверяем, есть ли уже точки, созданные с помощью service_points_improved.rb
if ServicePoint.count > 0
  puts "  Service points already exist (#{ServicePoint.count} found), skipping creation"
  puts "  If you want to recreate service points, run reset_db.sh script"
  exit
end

# Очищення існуючих записів
ServicePoint.destroy_all

# Дані міст з регионами
cities_data = [
  { id: 1, name: 'Київ', region_name: 'Київська область' },
  { id: 2, name: 'Львів', region_name: 'Львівська область' },
  { id: 3, name: 'Одеса', region_name: 'Одеська область' },
  { id: 4, name: 'Харків', region_name: 'Харківська область' },
  { id: 5, name: 'Дніпро', region_name: 'Дніпропетровська область' },
  { id: 6, name: 'Запоріжжя', region_name: 'Запорізька область' },
  { id: 7, name: 'Вінниця', region_name: 'Вінницька область' },
  { id: 8, name: 'Івано-Франківськ', region_name: 'Івано-Франківська область' },
  { id: 9, name: 'Тернопіль', region_name: 'Тернопільська область' },
  { id: 10, name: 'Житомир', region_name: 'Житомирська область' }
]

# Створення регіонів та міст
cities_data.each do |city_data|
  # Создаем или находим регион
  region = Region.find_or_create_by(name: city_data[:region_name])
  
  # Создаем или обновляем город
  city = City.find_or_initialize_by(id: city_data[:id])
  city.update!(name: city_data[:name], region: region)
end

puts "  Created #{cities_data.count} cities with regions"

# Отримання всіх партнерів
partners = Partner.all

if partners.empty?
  puts "  No partners found, please run partners seed first"
else
  # Дані сервісних точок - используем только доступных партнеров
  service_points_data = [
    # Київ - 3 точки
    {
      partner_id: partners[0].id,
      name: 'ШиноСервіс Експрес на Хрещатику',
      description: 'Повний спектр послуг з шиномонтажу та балансування коліс',
      city_id: 1, # Київ
      address: 'вул. Хрещатик, 22',
      contact_phone: '+380 67 123 45 67',
      is_active: true,
      work_status: 'working',
      post_count: 3, # Ограничиваем до 3 постов
      default_slot_duration: 30,
      latitude: 50.450001,
      longitude: 30.523333,
      rating: 4.7
    },
    {
      partner_id: partners[0].id,
      name: 'ШиноСервіс Експрес на Оболоні',
      description: 'Швидкий та якісний шиномонтаж для легкових автомобілів',
      city_id: 1, # Київ
      address: 'пр. Оболонський, 45',
      contact_phone: '+380 67 123 45 68',
      is_active: true,
      work_status: 'working',
      post_count: 2,
      default_slot_duration: 30,
      latitude: 50.501747,
      longitude: 30.497137,
      rating: 4.5
    },
    {
      partner_id: partners[1].id,
      name: 'АвтоШина Плюс на Позняках',
      description: 'Сучасний шиномонтаж з новітнім обладнанням',
      city_id: 1, # Київ
      address: 'вул. Драгоманова, 17',
      contact_phone: '+380 50 987 65 45',
      is_active: true,
      work_status: 'working',
      post_count: 1,
      default_slot_duration: 45,
      latitude: 50.411747,
      longitude: 30.627137,
      rating: 4.6
    },
    
    # Львів - 2 точки
    {
      partner_id: partners[1].id,
      name: 'АвтоШина Плюс центр',
      description: 'Професійний шиномонтаж та зберігання шин',
      city_id: 2, # Львів
      address: 'вул. Личаківська, 45',
      contact_phone: '+380 50 987 65 43',
      is_active: true,
      work_status: 'working',
      post_count: 3,
      default_slot_duration: 45,
      latitude: 49.842957,
      longitude: 24.031111,
      rating: 4.9
    },
    {
      partner_id: partners[1].id,
      name: 'АвтоШина Плюс на Сихові',
      description: 'Шиномонтаж та ремонт дисків',
      city_id: 2, # Львів
      address: 'пр. Червоної Калини, 35',
      contact_phone: '+380 50 987 65 44',
      is_active: true,
      work_status: 'temporarily_closed',
      post_count: 2,
      default_slot_duration: 30,
      latitude: 49.816721,
      longitude: 24.056284,
      rating: 4.2
    },
    
    # Одеса - 2 точки
    {
      partner_id: partners[2 % partners.count].id,
      name: 'ШинМайстер Одеса Центр',
      description: 'Найкращі послуги шиномонтажу в місті',
      city_id: 3, # Одеса
      address: 'вул. Дерибасівська, 12',
      contact_phone: '+380 63 555 55 55',
      is_active: true,
      work_status: 'working',
      post_count: 3,
      default_slot_duration: 40,
      latitude: 46.482526,
      longitude: 30.723309,
      rating: 4.6
    },
    {
      partner_id: partners[2 % partners.count].id,
      name: 'ШинМайстер Одеса Пересип',
      description: 'Швидкий шиномонтаж для всіх типів авто',
      city_id: 3, # Одеса
      address: 'вул. Чорноморського Козацтва, 70',
      contact_phone: '+380 63 555 55 56',
      is_active: true,
      work_status: 'working',
      post_count: 1,
      default_slot_duration: 35,
      latitude: 46.562526,
      longitude: 30.773309,
      rating: 4.3
    },
    
    # Харків - 1 точка
    {
      partner_id: partners[0].id,
      name: 'ШиноСервіс Експрес Харків',
      description: 'Якісне обслуговування та гарантія на роботи',
      city_id: 4, # Харків
      address: 'вул. Сумська, 25',
      contact_phone: '+380 67 123 45 69',
      is_active: true,
      work_status: 'working',
      post_count: 2,
      default_slot_duration: 30,
      latitude: 50.004747,
      longitude: 36.231137,
      rating: 4.4
    },
    
    # Дніпро - 1 точка
    {
      partner_id: partners[1].id,
      name: 'АвтоШина Плюс Дніпро',
      description: 'Комплексне обслуговування автомобілів',
      city_id: 5, # Дніпро
      address: 'пр. Дмитра Яворницького, 50',
      contact_phone: '+380 50 987 65 46',
      is_active: true,
      work_status: 'working',
      post_count: 3,
      default_slot_duration: 40,
      latitude: 48.464717,
      longitude: 35.046183,
      rating: 4.7
    },
    
    # Вінниця - 1 точка
    {
      partner_id: partners[2 % partners.count].id,
      name: 'ШинМайстер Вінниця',
      description: 'Професійна заміна та ремонт шин',
      city_id: 7, # Вінниця
      address: 'вул. Соборна, 30',
      contact_phone: '+380 63 555 55 57',
      is_active: true,
      work_status: 'working',
      post_count: 2,
      default_slot_duration: 35,
      latitude: 49.233083,
      longitude: 28.468217,
      rating: 4.5
    }
  ]

  # Створення сервісних точок
  service_points_data.each do |point_data|
    # Проверяем, существует ли уже точка с таким названием
    if ServicePoint.exists?(name: point_data[:name])
      puts "  Service point with name '#{point_data[:name]}' already exists, skipping"
      next
    end
    
    point = ServicePoint.create!(point_data)
    puts "  Created service point: #{point.name} (Partner: #{point.partner.company_name}, City: #{City.find(point_data[:city_id]).name})"
  end

  puts "Created #{ServicePoint.count} service points successfully!"

  # Создание индивидуальных постов обслуживания для каждой точки
  puts 'Creating service posts with individual slot durations...'
  
  ServicePoint.all.each do |service_point|
    # Пропускаем точки, у которых уже есть посты
    if service_point.service_posts.count > 0
      puts "  Service point #{service_point.name} already has #{service_point.service_posts.count} posts, skipping"
      next
    end
    
    puts "  Creating posts for #{service_point.name}..."
    
    # Определяем конфигурацию постов в зависимости от количества
    case service_point.post_count
    when 1
      # Точки с 1 постом
      posts_config = [
        { post_number: 1, name: "Универсальный пост", slot_duration: 40, description: "Универсальный пост для всех типов работ" }
      ]
    when 2
      # Точки с 2 постами
      posts_config = [
        { post_number: 1, name: "Экспресс пост", slot_duration: 25, description: "Быстрый шиномонтаж и балансировка" },
        { post_number: 2, name: "Стандартный пост", slot_duration: 45, description: "Стандартное обслуживание" }
      ]
    when 3
      # Точки с 3 постами
      posts_config = [
        { post_number: 1, name: "Экспресс пост", slot_duration: 20, description: "Быстрый шиномонтаж" },
        { post_number: 2, name: "Стандартный пост", slot_duration: 40, description: "Стандартное обслуживание" },
        { post_number: 3, name: "Грузовой пост", slot_duration: 60, description: "Обслуживание грузовых автомобилей" }
      ]
    else
      # Универсальная конфигурация для остальных (не должно использоваться)
      posts_config = []
      (1..service_point.post_count).each do |i|
        duration = case i
                  when 1 then 30
                  when 2 then 45
                  else 60
                  end
        posts_config << { post_number: i, name: "Пост #{i}", slot_duration: duration, description: "Обслуживание автомобилей" }
      end
    end
    
    # Создаем посты для точки
    posts_config.each do |post_config|
      ServicePost.create!(
        service_point: service_point,
        post_number: post_config[:post_number],
        name: post_config[:name],
        description: post_config[:description],
        slot_duration: post_config[:slot_duration],
        is_active: true
      )
      puts "    Created post: #{post_config[:name]} (#{post_config[:slot_duration]} min)"
    end
  end
end 