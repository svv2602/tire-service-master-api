# db/seeds/reset_and_seed_all.rb
# Скрипт для полного сброса и заполнения базы данных

puts "=== ПОЛНЫЙ СБРОС И ЗАПОЛНЕНИЕ БАЗЫ ДАННЫХ ==="
puts "Начинаем процесс..."

# Очистка всех таблиц
puts "\n=== ОЧИСТКА БАЗЫ ДАННЫХ ==="

# Отключаем внешние ключи для SQLite (если используется)
# ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = OFF;") if ActiveRecord::Base.connection.adapter_name == "SQLite"

# Удаляем записи из таблиц в определенном порядке
models_to_clear = [
  # Сначала удаляем таблицы, которые имеют внешние ключи на другие таблицы
  Article, # Добавляем таблицу articles, которая имеет внешний ключ на users
  ScheduleTemplate,
  ServicePost,
  ServicePointService,
  ServicePointAmenity,
  ServicePoint,
  Service,
  Amenity,
  ClientCar,
  Client,
  Operator,
  Partner,
  Administrator,
  # Затем удаляем таблицы, на которые ссылаются внешние ключи
  User,
  UserRole,
  City,
  Region
]

models_to_clear.each do |model|
  if ActiveRecord::Base.connection.table_exists?(model.table_name)
    begin
      count = model.count
      model.delete_all
      puts "  ✓ Удалено #{count} записей из таблицы #{model.table_name}"
    rescue => e
      puts "  ✗ Ошибка при очистке таблицы #{model.table_name}: #{e.message}"
    end
  else
    puts "  ⚠ Таблица #{model.table_name} не существует, пропускаем"
  end
end

# Включаем внешние ключи обратно
# ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = ON;") if ActiveRecord::Base.connection.adapter_name == "SQLite"

puts "База данных очищена."

# Сбрасываем счетчики автоинкремента для PostgreSQL
if ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
  puts "\n=== СБРОС СЧЕТЧИКОВ АВТОИНКРЕМЕНТА ==="
  models_to_clear.each do |model|
    if ActiveRecord::Base.connection.table_exists?(model.table_name)
      begin
        ActiveRecord::Base.connection.execute("ALTER SEQUENCE #{model.table_name}_id_seq RESTART WITH 1;")
        puts "  ✓ Сброшен счетчик для таблицы #{model.table_name}"
      rescue => e
        puts "  ✗ Ошибка при сбросе счетчика для #{model.table_name}: #{e.message}"
      end
    end
  end
end

# Загрузка данных в правильном порядке
puts "\n=== ЗАГРУЗКА ДАННЫХ ==="

# 1. Загружаем роли пользователей
puts "\n--- Загрузка ролей пользователей ---"
load 'db/seeds/user_roles.rb'

# 2. Создаем администратора
puts "\n--- Создание администратора ---"
load 'db/seeds/create_admin_user.rb'

# 3. Загружаем тестовых пользователей
puts "\n--- Загрузка тестовых пользователей ---"
load 'db/seeds/test_users.rb'

# 4. Загружаем партнеров
puts "\n--- Загрузка партнеров ---"
load 'db/seeds/partners.rb'

# 4.5. Загружаем регионы и города
puts "\n--- Загрузка регионов и городов ---"
load 'db/seeds/regions_and_cities.rb'

# 5. Загружаем сервисные точки с уникальными названиями
puts "\n--- Загрузка сервисных точек ---"
# Удаляем все тестовые точки, чтобы избежать дублирования
puts "  Удаление старых тестовых точек..."
ServicePoint.where("name LIKE 'Тестовая точка%'").destroy_all
# Загружаем новые улучшенные точки
load 'db/seeds/service_points_improved.rb'

# 6. Загружаем расписание для точек
puts "\n--- Загрузка расписания для точек ---"
load 'db/seeds/schedule_generation.rb'

# 7. Загружаем клиентов и их автомобили
puts "\n--- Загрузка клиентов и их автомобилей ---"
load 'db/seeds/clients.rb'

puts "\n=== ЗАПОЛНЕНИЕ БАЗЫ ДАННЫХ ЗАВЕРШЕНО ==="
puts "Проверка количества записей:"

puts "  Роли пользователей: #{UserRole.count}"
puts "  Пользователи: #{User.count}"
puts "  Администраторы: #{Administrator.count}"
puts "  Партнеры: #{Partner.count}"
puts "  Регионы: #{Region.count}"
puts "  Города: #{City.count}"
puts "  Сервисные точки: #{ServicePoint.count}"
puts "  Сервисные посты: #{ServicePost.count}"
puts "  Шаблоны расписания: #{ScheduleTemplate.count}"
puts "  Клиенты: #{Client.count}"
puts "  Автомобили клиентов: #{ClientCar.count}"

puts "\n=== ПРОЦЕСС ЗАВЕРШЕН ===" 