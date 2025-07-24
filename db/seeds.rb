# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "=== Начало загрузки тестовых данных ==="

# Приоритетные сидеры (должны выполняться в определенном порядке)
priority_seeds = [
  'user_roles.rb',           # Сначала создаем роли пользователей
  'test_users.rb',           # Создаем тестовых пользователей с разными ролями
  '02_regions_and_cities.rb',   # Создаем регионы и города
  'partners.rb',             # Создаем партнеров
  'clients.rb',              # Создаем клиентов
  'car_types.rb',            # Создаем типы автомобилей
  'car_brands_and_models.rb', # Создаем бренды и модели автомобилей
  'services_localized.rb',   # Создаем локализованные услуги для сервисных точек
  'service_points_improved.rb', # Создаем сервисные точки
  'schedule_generation.rb',  # Создаем шаблоны расписания
  '04_service_point_photos.rb', # Добавляем фотографии сервисных точек
  '05_reviews.rb',           # Создаем отзывы
  'notification_settings.rb', # Создаем настройки системы уведомлений
  'custom_variables.rb',     # Создаем кастомные переменные для email шаблонов
  'essential_email_templates.rb', # Создаем основные шаблоны email уведомлений
  'telegram_templates.rb',   # Создаем Telegram шаблоны уведомлений
  'push_templates.rb',       # Создаем Push шаблоны уведомлений
  'articles_multilang.rb',   # Создаем многоязычные статьи
  'page_content.rb'          # Создаем контент страниц
]

# Исключаемые файлы (устаревшие или временные)
excluded_seeds = [
  'articles.rb',             # Старый файл статей
  'articles_ru.rb',          # Старый файл русских статей
  'create_ukrainian_articles.rb', # Временный файл
  'reset_and_seed_all.rb',   # Файл полного сброса БД (запускается отдельно)
  'create_admin_user.rb',    # Удален (дублировал test_users.rb)
  'test_data.rb',            # Удален (ошибки валидации)
  'services.rb',             # Старый файл услуг без локализации
  '03_services.rb',          # Старый файл услуг без локализации
  'generate_test_data.rb',   # Удален (тестовые бронирования больше не нужны)
  'fix_test_data.rb',        # Удален (тестовые данные больше не нужны)
  'test_booking_statuses.rb', # Удален (тестовые статусы бронирований больше не нужны)
  'email_templates.rb',      # Файл не существует (используется essential_email_templates.rb)
  'extended_email_templates.rb', # Создает лишние шаблоны
  'complete_email_templates.rb' # Содержит destroy_all и пересоздает все шаблоны
]

# Сначала выполняем приоритетные сидеры в заданном порядке
priority_seeds.each do |seed_name|
  seed_path = File.join(Rails.root, 'db', 'seeds', seed_name)
  if File.exist?(seed_path)
    puts "\n=== Загрузка приоритетного файла сидов: #{seed_name} ==="
    begin
      load seed_path
    rescue => e
      puts "Ошибка при загрузке #{seed_name}: #{e.message}"
      puts e.backtrace.join("\n")
    end
  else
    puts "\n=== Файл #{seed_name} не найден, пропускаем ==="
  end
end

# Примечание: schedule_generation.rb уже загружен в приоритетных сидах

# Загрузка SEO метатегов
load Rails.root.join('db', 'seeds', 'seo_metatags.rb')

# Затем выполняем остальные сидеры
Dir[File.join(Rails.root, 'db', 'seeds', '*.rb')].sort.each do |seed|
  seed_name = File.basename(seed)
  # Пропускаем уже выполненные приоритетные сидеры и исключенные файлы
  unless priority_seeds.include?(seed_name) || excluded_seeds.include?(seed_name)
    puts "\n=== Загрузка файла сидов: #{seed_name} ==="
    begin
      load seed
    rescue => e
      puts "Ошибка загрузки сида #{seed_name}: #{e.message}"
      puts e.backtrace.join("\n")
    end
  end
end

puts "\n=== Все сиды загружены успешно! ==="
puts "\nТестовые учетные данные для входа:"
puts "Админ:    admin@test.com / admin123"
puts "Менеджер: manager@test.com / manager123"
puts "Оператор: operator@test.com / operator123"
puts "Партнер:  partner@test.com / partner123"
puts "Клиент:   client@test.com / client123"
puts "==================================="
