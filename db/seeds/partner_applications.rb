# db/seeds/partner_applications.rb
# Создание тестовых заявок партнеров

puts '=== Создание тестовых заявок партнеров ==='

# Получаем существующие регионы и города
regions = Region.limit(5)
cities = City.limit(10)
admin_user = User.joins(:role).where(user_roles: { name: 'admin' }).first
manager_user = User.joins(:role).where(user_roles: { name: 'manager' }).first

# Очищаем существующие тестовые заявки
PartnerApplication.destroy_all

# Данные для тестовых заявок
applications_data = [
  {
    company_name: 'ШиноСервіс Київ',
    business_description: 'Професійний шиномонтаж з досвідом роботи більше 10 років. Надаємо повний спектр послуг з обслуговування шин та дисків.',
    contact_person: 'Іван Петренко',
    email: 'ivan.petrenko@shinoservice.com.ua',
    phone: '+380671234567',
    city: 'Київ',
    address: 'вул. Хрещатик, 15',
    website: 'https://shinoservice.com.ua',
    additional_info: 'Маємо власне обладнання та команду досвідчених майстрів',
    expected_service_points: 2,
    status: 'new',
    region: regions.first,
    city_record: cities.first
  },
  {
    company_name: 'Авто-Шина Львів',
    business_description: 'Сучасний автосервіс з повним циклом обслуговування автомобілів. Спеціалізуємося на шиномонтажі та балансуванні.',
    contact_person: 'Марія Коваленко',
    email: 'maria@avtoshina-lviv.ua',
    phone: '+380509876543',
    city: 'Львів',
    address: 'пр. Свободи, 28',
    website: 'https://avtoshina-lviv.ua',
    additional_info: 'Працюємо з легковими та вантажними автомобілями',
    expected_service_points: 1,
    status: 'in_progress',
    region: regions.second,
    city_record: cities.second,
    processed_by: admin_user,
    processed_at: 2.days.ago
  },
  {
    company_name: 'Експрес-Шина Одеса',
    business_description: 'Швидкий та якісний шиномонтаж в центрі Одеси. Гарантуємо професійне обслуговування та доступні ціни.',
    contact_person: 'Олександр Сидоренко',
    email: 'alex@express-shina.od.ua',
    phone: '+380632345678',
    city: 'Одеса',
    address: 'вул. Дерибасівська, 45',
    website: nil,
    additional_info: 'Можливість виїзду до клієнта',
    expected_service_points: 3,
    status: 'approved',
    region: regions.third,
    city_record: cities.third,
    processed_by: manager_user,
    processed_at: 1.day.ago,
    admin_notes: 'Відмінні рекомендації, досвід роботи підтверджено'
  },
  {
    company_name: 'Шини-Плюс Харків',
    business_description: 'Мережа шиномонтажних майстерень у Харкові. Пропонуємо професійні послуги та продаж автомобільних шин.',
    contact_person: 'Сергій Мельник',
    email: 'sergey@shini-plus.kh.ua',
    phone: '+380577654321',
    city: 'Харків',
    address: 'вул. Сумська, 67',
    website: 'https://shini-plus.kh.ua',
    additional_info: 'Власний склад шин, можливість оптових поставок',
    expected_service_points: 4,
    status: 'rejected',
    region: regions.fourth,
    city_record: cities.fourth,
    processed_by: admin_user,
    processed_at: 3.days.ago,
    admin_notes: 'Недостатньо документів для підтвердження діяльності'
  },
  {
    company_name: 'Мобільний Шиномонтаж',
    business_description: 'Інноваційний сервіс мобільного шиномонтажу. Приїжджаємо до клієнта в будь-який час та в будь-яке місце.',
    contact_person: 'Андрій Кравченко',
    email: 'andrey@mobile-tire.com.ua',
    phone: '+380951112233',
    city: 'Дніпро',
    address: 'пр. Гагаріна, 72',
    website: 'https://mobile-tire.com.ua',
    additional_info: 'Працюємо 24/7, власний автопарк обладнаних автомобілів',
    expected_service_points: 1,
    status: 'connected',
    region: regions.fifth,
    city_record: cities.fifth,
    processed_by: admin_user,
    processed_at: 5.days.ago,
    admin_notes: 'Успішно підключено, партнерський договір підписано'
  },
  {
    company_name: 'ТехноШина Запоріжжя',
    business_description: 'Технологічний центр обслуговування шин з використанням сучасного європейського обладнання.',
    contact_person: 'Наталія Бондаренко',
    email: 'natalia@technoshina.zp.ua',
    phone: '+380612223344',
    city: 'Запоріжжя',
    address: 'вул. Соборна, 89',
    website: 'https://technoshina.zp.ua',
    additional_info: 'Сертифіковані майстри, гарантія на всі роботи',
    expected_service_points: 2,
    status: 'new'
  }
]

# Створення заявок
created_count = 0
applications_data.each do |app_data|
  begin
    application = PartnerApplication.new(app_data)
    
    if application.save
      puts "  ✅ Створена заявка: #{application.company_name} (#{application.status_label})"
      created_count += 1
    else
      puts "  ❌ Помилка створення заявки #{app_data[:company_name]}: #{application.errors.full_messages.join(', ')}"
    end
  rescue => e
    puts "  ❌ Виняток при створенні заявки #{app_data[:company_name]}: #{e.message}"
  end
end

puts "\n📊 Результат:"
puts "  Створено заявок: #{created_count}"
puts "  Всього заявок в БД: #{PartnerApplication.count}"

# Статистика по статусам
status_stats = PartnerApplication.group(:status).count
puts "\n📈 Статистика по статусам:"
status_stats.each do |status, count|
  puts "  #{PartnerApplication.new(status: status).status_label}: #{count}"
end

puts "\n✅ Тестові заявки партнерів створені успішно!" 