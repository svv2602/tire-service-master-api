# db/seeds_new.rb
# Улучшенная система загрузки seeds с полной очисткой БД и динамическими ID

puts "🚀 === УЛУЧШЕННАЯ СИСТЕМА ЗАГРУЗКИ SEEDS ==="
puts "Начинаем процесс полной перезагрузки базы данных..."

# Проверяем окружение
if Rails.env.production? && ENV['ALLOW_PRODUCTION_SEED'] != 'true'
  puts "❌ ВНИМАНИЕ: Загрузка seeds в production окружении заблокирована!"
  puts "   Для разрешения установите переменную: ALLOW_PRODUCTION_SEED=true"
  exit 1
end

# Засекаем время выполнения
start_time = Time.current

# =============================================================================
# ЭТАП 1: ПОЛНАЯ ОЧИСТКА БАЗЫ ДАННЫХ
# =============================================================================

puts "\n🧹 === ЭТАП 1: ПОЛНАЯ ОЧИСТКА БАЗЫ ДАННЫХ ==="

if ENV['SKIP_RESET'] != 'true'
  # Загружаем и выполняем скрипт очистки
  load File.join(Rails.root, 'db', 'seeds', '00_database_reset.rb')
  DatabaseReset.perform!
else
  puts "⚠️  Очистка базы данных пропущена (SKIP_RESET=true)"
end

# =============================================================================
# ЭТАП 2: ЗАГРУЗКА БАЗОВЫХ ДАННЫХ
# =============================================================================

puts "\n📚 === ЭТАП 2: ЗАГРУЗКА БАЗОВЫХ ДАННЫХ ==="

# Приоритетные seed файлы в строгом порядке
priority_seeds = [
  '01_user_roles.rb',           # Роли пользователей (основа системы)
  '02_regions_and_cities.rb',   # Географические данные
  '03_services.rb',             # Категории услуг и услуги
  'car_types.rb',               # Типы автомобилей
  'car_brands_and_models.rb',   # Бренды и модели автомобилей
  'booking_statuses.rb',        # Статусы бронирований
  'payment_statuses.rb'         # Статусы платежей
]

# Счетчик успешно загруженных файлов
loaded_files = 0
failed_files = []

priority_seeds.each do |seed_name|
  seed_path = File.join(Rails.root, 'db', 'seeds', seed_name)
  
  if File.exist?(seed_path)
    puts "\n📂 Загрузка: #{seed_name}"
    begin
      load seed_path
      loaded_files += 1
      puts "  ✅ Успешно загружен: #{seed_name}"
    rescue => e
      puts "  ❌ Ошибка загрузки #{seed_name}: #{e.message}"
      puts "     #{e.backtrace.first(3).join("\n     ")}"
      failed_files << seed_name
    end
  else
    puts "  ⚠️  Файл не найден: #{seed_name}"
    failed_files << seed_name
  end
end

# =============================================================================
# ЭТАП 3: ЗАГРУЗКА ПОЛЬЗОВАТЕЛЕЙ И СВЯЗАННЫХ ДАННЫХ
# =============================================================================

puts "\n👥 === ЭТАП 3: ЗАГРУЗКА ПОЛЬЗОВАТЕЛЕЙ И СВЯЗАННЫХ ДАННЫХ ==="

user_seeds = [
  'create_admin_user.rb',       # Основной администратор
  'test_users.rb',              # Тестовые пользователи
  'partners.rb',                # Партнеры
  'clients.rb'                  # Клиенты
]

user_seeds.each do |seed_name|
  seed_path = File.join(Rails.root, 'db', 'seeds', seed_name)
  
  if File.exist?(seed_path)
    puts "\n👤 Загрузка: #{seed_name}"
    begin
      load seed_path
      loaded_files += 1
      puts "  ✅ Успешно загружен: #{seed_name}"
    rescue => e
      puts "  ❌ Ошибка загрузки #{seed_name}: #{e.message}"
      puts "     #{e.backtrace.first(3).join("\n     ")}"
      failed_files << seed_name
    end
  else
    puts "  ⚠️  Файл не найден: #{seed_name}"
  end
end

# =============================================================================
# ЭТАП 4: ЗАГРУЗКА СЕРВИСНЫХ ТОЧЕК И РАСПИСАНИЙ
# =============================================================================

puts "\n🏢 === ЭТАП 4: ЗАГРУЗКА СЕРВИСНЫХ ТОЧЕК И РАСПИСАНИЙ ==="

service_seeds = [
  'service_points_improved.rb', # Сервисные точки
  'schedule_generation.rb'      # Расписания
]

service_seeds.each do |seed_name|
  seed_path = File.join(Rails.root, 'db', 'seeds', seed_name)
  
  if File.exist?(seed_path)
    puts "\n🏢 Загрузка: #{seed_name}"
    begin
      load seed_path
      loaded_files += 1
      puts "  ✅ Успешно загружен: #{seed_name}"
    rescue => e
      puts "  ❌ Ошибка загрузки #{seed_name}: #{e.message}"
      puts "     #{e.backtrace.first(3).join("\n     ")}"
      failed_files << seed_name
    end
  else
    puts "  ⚠️  Файл не найден: #{seed_name}"
  end
end

# =============================================================================
# ЭТАП 5: ЗАГРУЗКА КОНТЕНТА И ДОПОЛНИТЕЛЬНЫХ ДАННЫХ
# =============================================================================

puts "\n📄 === ЭТАП 5: ЗАГРУЗКА КОНТЕНТА И ДОПОЛНИТЕЛЬНЫХ ДАННЫХ ==="

content_seeds = [
  'page_content.rb',            # Контент страниц
  'articles_multilang.rb'       # Многоязычные статьи
]

content_seeds.each do |seed_name|
  seed_path = File.join(Rails.root, 'db', 'seeds', seed_name)
  
  if File.exist?(seed_path)
    puts "\n📄 Загрузка: #{seed_name}"
    begin
      load seed_path
      loaded_files += 1
      puts "  ✅ Успешно загружен: #{seed_name}"
    rescue => e
      puts "  ❌ Ошибка загрузки #{seed_name}: #{e.message}"
      puts "     #{e.backtrace.first(3).join("\n     ")}"
      failed_files << seed_name
    end
  else
    puts "  ⚠️  Файл не найден: #{seed_name}"
  end
end

# =============================================================================
# ЭТАП 6: ПРОВЕРКА ПОСЛЕДОВАТЕЛЬНОСТЕЙ
# =============================================================================

puts "\n🔢 === ЭТАП 6: ПРОВЕРКА ПОСЛЕДОВАТЕЛЬНОСТЕЙ ==="

if ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
  begin
    require File.join(Rails.root, 'app', 'models', 'concerns', 'database_sequences.rb')
    DatabaseSequences.check_all_sequences
    puts "  ✅ Все последовательности проверены и исправлены"
  rescue => e
    puts "  ⚠️  Ошибка проверки последовательностей: #{e.message}"
  end
else
  puts "  ℹ️  Проверка последовательностей доступна только для PostgreSQL"
end

# =============================================================================
# ФИНАЛЬНАЯ СТАТИСТИКА
# =============================================================================

end_time = Time.current
execution_time = (end_time - start_time).round(2)

puts "\n📊 === ФИНАЛЬНАЯ СТАТИСТИКА ==="
puts "⏱️  Время выполнения: #{execution_time} секунд"
puts "✅ Успешно загружено файлов: #{loaded_files}"

if failed_files.any?
  puts "❌ Не удалось загрузить файлы: #{failed_files.join(', ')}"
else
  puts "🎉 Все файлы загружены успешно!"
end

# Статистика по таблицам
puts "\n📈 Количество записей в основных таблицах:"
stats = {
  'Роли пользователей' => UserRole.count,
  'Пользователи' => User.count,
  'Администраторы' => Administrator.count,
  'Партнеры' => Partner.count,
  'Клиенты' => Client.count,
  'Регионы' => Region.count,
  'Города' => City.count,
  'Категории услуг' => ServiceCategory.count,
  'Услуги' => Service.count,
  'Сервисные точки' => ServicePoint.count,
  'Сервисные посты' => ServicePost.count,
  'Шаблоны расписания' => ScheduleTemplate.count,
  'Статьи' => Article.count
}

stats.each do |name, count|
  puts "  #{name}: #{count}"
end

puts "\n🔑 === ТЕСТОВЫЕ УЧЕТНЫЕ ДАННЫЕ ==="
puts "Для входа в систему используйте:"
puts "  👑 Администратор: admin@test.com / admin123"
puts "  👔 Менеджер: manager@test.com / manager123"
puts "  👨‍💼 Оператор: operator@test.com / operator123"
puts "  🤝 Партнер: partner@test.com / partner123"
puts "  👤 Клиент: client@test.com / client123"

puts "\n🎯 === ПРОЦЕСС ЗАВЕРШЕН ==="
puts "База данных полностью перезагружена и готова к использованию!"

# Проверяем критические зависимости
critical_checks = []

critical_checks << "❌ Нет ролей пользователей" if UserRole.count == 0
critical_checks << "❌ Нет администратора" if Administrator.count == 0
critical_checks << "❌ Нет регионов" if Region.count == 0
critical_checks << "❌ Нет городов" if City.count == 0
critical_checks << "❌ Нет услуг" if Service.count == 0

if critical_checks.any?
  puts "\n⚠️  КРИТИЧЕСКИЕ ПРОБЛЕМЫ:"
  critical_checks.each { |check| puts "  #{check}" }
  puts "  Система может работать некорректно!"
else
  puts "\n✅ Все критические компоненты загружены успешно!"
end 