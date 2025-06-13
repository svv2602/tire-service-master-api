# db/seeds/service_points_improved.rb
# Створення тестових даних для точок обслуговування з покращеними назвами

puts 'Creating service points with improved names...'

# Очищення існуючих записів
ServicePoint.destroy_all
ServicePost.destroy_all

# Отримання всіх партнерів
partners = Partner.all

if partners.empty?
  puts "  No partners found, please run partners seed first"
else
  # Перевіряємо наявність міст
  if City.count == 0
    puts "  No cities found, please run regions_and_cities seed first"
    return
  end
  
  # Отримуємо міста з бази даних
  cities = {
    'Київ' => City.find_by(name: 'Київ'),
    'Львів' => City.find_by(name: 'Львів'),
    'Одеса' => City.find_by(name: 'Одеса'),
    'Харків' => City.find_by(name: 'Харків'),
    'Дніпро' => City.find_by(name: 'Дніпро'),
    'Вінниця' => City.find_by(name: 'Вінниця')
  }
  
  # Перевіряємо, що всі міста знайдені
  missing_cities = cities.select { |name, city| city.nil? }.keys
  if missing_cities.any?
    puts "  Missing cities in database: #{missing_cities.join(', ')}"
    puts "  Please ensure all required cities exist in the database"
    return
  end

  # Дані сервісних точек с улучшенными названиями
  service_points_data = [
    # Київ - 3 точки
    {
      partner_id: partners[0].id,
      name: 'ШиноМайстер Преміум Хрещатик',
      description: 'Преміум-сервіс з шиномонтажу та балансування коліс у самому центрі Києва',
      city_id: cities['Київ'].id,
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
      name: 'ШиноМайстер Експрес Оболонь',
      description: 'Швидкий та якісний шиномонтаж для легкових автомобілів на Оболоні',
      city_id: cities['Київ'].id,
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
      name: 'АвтоШина 24/7 Позняки',
      description: 'Цілодобовий сучасний шиномонтаж з новітнім обладнанням',
      city_id: cities['Київ'].id,
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
      name: 'АвтоШина Преміум Центр Львів',
      description: 'Професійний шиномонтаж та зберігання шин у центрі Львова',
      city_id: cities['Львів'].id,
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
      name: 'АвтоШина Стандарт Сихів',
      description: 'Шиномонтаж та ремонт дисків для всіх типів автомобілів',
      city_id: cities['Львів'].id,
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
      name: 'ШиноСервіс VIP Дерибасівська',
      description: 'Найкращі послуги шиномонтажу в самому серці Одеси',
      city_id: cities['Одеса'].id,
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
      name: 'ШиноСервіс Економ Пересип',
      description: 'Доступний шиномонтаж для всіх типів авто на Пересипі',
      city_id: cities['Одеса'].id,
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
      name: 'ШиноМайстер Преміум Харків',
      description: 'Якісне обслуговування та гарантія на всі види робіт',
      city_id: cities['Харків'].id,
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
      name: 'АвтоШина Комплекс Дніпро',
      description: 'Комплексне обслуговування автомобілів у центрі Дніпра',
      city_id: cities['Дніпро'].id,
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
      name: 'ШиноСервіс Стандарт Вінниця',
      description: 'Професійна заміна та ремонт шин у центрі Вінниці',
      city_id: cities['Вінниця'].id,
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
    post_count = point_data[:post_count]
    point_data = point_data.except(:post_count)  # Удаляем post_count из хеша перед созданием
    
    point = ServicePoint.create!(point_data)
    city_name = City.find(point_data[:city_id]).name
    puts "  Created service point: #{point.name} (Partner: #{point.partner.company_name}, City: #{city_name})"
    
    # Создание индивидуальных постов обслуживания для каждой точки
    puts "    Creating #{post_count} posts for #{point.name}..."
    
    # Определяем конфигурацию постов в зависимости от количества
    posts_config = case post_count
    when 1
      # Точки с 1 постом
      [
        { post_number: 1, name: "Універсальний пост", slot_duration: 40, description: "Універсальний пост для всіх типів робіт" }
      ]
    when 2
      # Точки с 2 постами
      [
        { post_number: 1, name: "Експрес-пост", slot_duration: 25, description: "Швидкий шиномонтаж та балансування" },
        { post_number: 2, name: "Стандартний пост", slot_duration: 45, description: "Стандартне обслуговування" }
      ]
    when 3
      # Точки с 3 постами
      [
        { post_number: 1, name: "Експрес-пост", slot_duration: 20, description: "Швидкий шиномонтаж" },
        { post_number: 2, name: "Стандартний пост", slot_duration: 40, description: "Стандартне обслуговування" },
        { post_number: 3, name: "Вантажний пост", slot_duration: 60, description: "Обслуговування вантажних автомобілів" }
      ]
    else
      # Универсальная конфигурация для остальных (не должно использоваться)
      Array.new(post_count) do |i|
        duration = case i+1
                  when 1 then 30
                  when 2 then 45
                  else 60
                  end
        { post_number: i+1, name: "Пост #{i+1}", slot_duration: duration, description: "Стандартний пост обслуговування" }
      end
    end
    
    # Создаем посты для текущей точки
    posts_config.each do |post_config|
      service_post = ServicePost.create!(
        service_point: point,
        post_number: post_config[:post_number],
        name: post_config[:name],
        description: post_config[:description],
        slot_duration: post_config[:slot_duration],
        is_active: true
      )
      puts "      Created post: #{service_post.name} (#{service_post.slot_duration} min)"
    end
  end

  puts "Created #{ServicePoint.count} service points with #{ServicePost.count} service posts successfully!"
end 