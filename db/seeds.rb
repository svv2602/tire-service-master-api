# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "=== Начало загрузки тестовых данных ==="

# Приоритетные сидеры (должны выполняться в определенном порядке)
priority_seeds = [
  'user_roles.rb',           # Сначала создаем роли пользователей
  'create_admin_user.rb',    # Создаем основного администратора
  'test_users.rb',           # Создаем тестовых пользователей с разными ролями
  'partners.rb',             # Создаем партнеров
  'clients.rb',              # Создаем клиентов
  'car_types.rb',            # Создаем типы автомобилей
  'car_brands_and_models.rb', # Создаем бренды и модели автомобилей
  'schedule_generation.rb'   # Создаем шаблоны расписания
]

# Сначала выполняем приоритетные сидеры
priority_seeds.each do |seed_name|
  seed_path = File.join(Rails.root, 'db', 'seeds', seed_name)
  if File.exist?(seed_path)
    puts "\n=== Загрузка приоритетного файла сидов: #{seed_name} ==="
    load seed_path
  else
    puts "Предупреждение: Приоритетный файл сидов не найден: #{seed_name}"
  end
end

# Затем выполняем остальные сидеры
Dir[File.join(Rails.root, 'db', 'seeds', '*.rb')].sort.each do |seed|
  seed_name = File.basename(seed)
  # Пропускаем уже выполненные приоритетные сидеры
  unless priority_seeds.include?(seed_name)
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
