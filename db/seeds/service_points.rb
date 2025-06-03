# db/seeds/service_points.rb
# Створення тестових даних для точок обслуговування

puts 'Creating service points...'

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
    {
      partner_id: partners[0].id,
      name: 'ШиноСервіс Експрес на Хрещатику',
      description: 'Повний спектр послуг з шиномонтажу та балансування коліс',
      city_id: 1, # Київ
      address: 'вул. Хрещатик, 22',
      contact_phone: '+380 67 123 45 67',
      is_active: true,
      work_status: 'working',
      post_count: 4,
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
      post_count: 3,
      default_slot_duration: 30,
      latitude: 50.501747,
      longitude: 30.497137,
      rating: 4.5
    },
    {
      partner_id: partners[1].id,
      name: 'АвтоШина Плюс центр',
      description: 'Професійний шиномонтаж та зберігання шин',
      city_id: 2, # Львів
      address: 'вул. Личаківська, 45',
      contact_phone: '+380 50 987 65 43',
      is_active: true,
      work_status: 'working',
      post_count: 5,
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
    }
  ]
  
  # Добавляем больше точек если партнеров достаточно
  if partners.count >= 3
    service_points_data << {
      partner_id: partners[2].id,
      name: 'ШинМайстер Одеса',
      description: 'Найкращі послуги шиномонтажу в місті',
      city_id: 3, # Одеса
      address: 'вул. Дерибасівська, 12',
      contact_phone: '+380 63 555 55 55',
      is_active: true,
      work_status: 'working',
      post_count: 4,
      default_slot_duration: 40,
      latitude: 46.482526,
      longitude: 30.723309,
      rating: 4.6
    }
  end

  # Створення сервісних точок
  service_points_data.each do |point_data|
    point = ServicePoint.create!(point_data)
    puts "  Created service point: #{point.name} (Partner: #{point.partner.company_name})"
  end

  puts "Created #{ServicePoint.count} service points successfully!"

  # Создание индивидуальных постов обслуживания для каждой точки
  puts 'Creating service posts with individual slot durations...'
  
  ServicePoint.all.each do |service_point|
    puts "  Creating posts for #{service_point.name}..."
    
    # Очищаем существующие посты для этой точки
    service_point.service_posts.destroy_all
    
    # Определяем конфигурацию постов в зависимости от типа точки
    case service_point.post_count
    when 2
      # Маленькие точки - 2 поста
      posts_config = [
        { post_number: 1, name: "Экспресс пост", slot_duration: 20, description: "Быстрый шиномонтаж" },
        { post_number: 2, name: "Стандартный пост", slot_duration: 45, description: "Стандартное обслуживание" }
      ]
    when 3
      # Средние точки - 3 поста
      posts_config = [
        { post_number: 1, name: "Быстрый пост", slot_duration: 30, description: "Быстрое обслуживание легковых авто" },
        { post_number: 2, name: "Универсальный пост", slot_duration: 60, description: "Стандартное обслуживание" },
        { post_number: 3, name: "Грузовой пост", slot_duration: 90, description: "Обслуживание грузовых автомобилей" }
      ]
    when 4
      # Стандартные точки - 4 поста
      posts_config = [
        { post_number: 1, name: "Экспресс пост 1", slot_duration: 25, description: "Быстрый шиномонтаж и балансировка" },
        { post_number: 2, name: "Экспресс пост 2", slot_duration: 25, description: "Быстрый шиномонтаж и балансировка" },
        { post_number: 3, name: "Универсальный пост", slot_duration: 60, description: "Полное обслуживание легковых авто" },
        { post_number: 4, name: "Комплексный пост", slot_duration: 120, description: "Сложные работы и ремонт дисков" }
      ]
    when 5
      # Большие точки - 5 постов
      posts_config = [
        { post_number: 1, name: "Экспресс пост 1", slot_duration: 30, description: "Быстрое обслуживание" },
        { post_number: 2, name: "Экспресс пост 2", slot_duration: 30, description: "Быстрое обслуживание" },
        { post_number: 3, name: "Стандартный пост 1", slot_duration: 60, description: "Стандартное обслуживание" },
        { post_number: 4, name: "Стандартный пост 2", slot_duration: 60, description: "Стандартное обслуживание" },
        { post_number: 5, name: "Грузовой пост", slot_duration: 120, description: "Обслуживание коммерческого транспорта" }
      ]
    when 6
      # Очень большие точки - 6 постов
      posts_config = [
        { post_number: 1, name: "Быстрый пост 1", slot_duration: 20, description: "Экспресс шиномонтаж" },
        { post_number: 2, name: "Быстрый пост 2", slot_duration: 20, description: "Экспресс шиномонтаж" },
        { post_number: 3, name: "Стандартный пост 1", slot_duration: 45, description: "Стандартное обслуживание" },
        { post_number: 4, name: "Стандартный пост 2", slot_duration: 45, description: "Стандартное обслуживание" },
        { post_number: 5, name: "Премиум пост", slot_duration: 90, description: "Премиум обслуживание" },
        { post_number: 6, name: "Грузовой пост", slot_duration: 150, description: "Грузовые автомобили и спецтехника" }
      ]
    else
      # Универсальная конфигурация для остальных
      posts_config = []
      (1..service_point.post_count).each do |i|
        duration = case i
                  when 1..2 then 30  # Первые 2 поста - быстрые
                  when 3..4 then 60  # Средние посты - стандартные
                  else 90            # Остальные - долгие
                  end
        posts_config << {
          post_number: i,
          name: "Пост #{i}",
          slot_duration: duration,
          description: "Автоматически созданный пост №#{i}"
        }
      end
    end
    
    # Создаем посты для данной точки
    posts_config.each do |post_config|
      service_post = service_point.service_posts.create!(
        post_number: post_config[:post_number],
        name: post_config[:name],
        slot_duration: post_config[:slot_duration],
        description: post_config[:description],
        is_active: true
      )
      puts "    Created #{service_post.display_name} (#{service_post.slot_duration} мин)"
    end
  end
  
  total_posts = ServicePost.count
  puts "Created #{total_posts} service posts with individual configurations!"
  
  # Выводим сводку по конфигурациям
  puts "\nService posts summary:"
  ServicePoint.includes(:service_posts).each do |sp|
    puts "  #{sp.name}: #{sp.service_posts.count} постов"
    sp.service_posts.ordered_by_post_number.each do |post|
      puts "    - #{post.display_name}: #{post.slot_duration} мин"
    end
  end
end 