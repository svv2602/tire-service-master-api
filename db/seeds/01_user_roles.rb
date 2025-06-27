# db/seeds/01_user_roles.rb
# Создание ролей пользователей с динамическими ID

puts '=== Создание ролей пользователей ==='

# Данные ролей в правильном порядке создания
roles_data = [
  {
    name: 'admin',
    description: 'Администратор системы с полными правами',
    is_active: true
  },
  {
    name: 'manager',
    description: 'Менеджер партнера с правами управления сервисными точками',
    is_active: true
  },
  {
    name: 'operator',
    description: 'Оператор сервисной точки',
    is_active: true
  },
  {
    name: 'partner',
    description: 'Партнер с правами управления своими сервисными точками',
    is_active: true
  },
  {
    name: 'client',
    description: 'Клиент системы',
    is_active: true
  }
]

# Создание ролей с проверкой существования
created_count = 0
updated_count = 0

roles_data.each do |role_data|
  role = UserRole.find_or_initialize_by(name: role_data[:name])
  
  if role.persisted?
    # Обновляем существующую роль
    if role.update(role_data)
      puts "  ✅ Обновлена роль: #{role.name} (ID: #{role.id})"
      updated_count += 1
    else
      puts "  ❌ Ошибка обновления роли #{role_data[:name]}: #{role.errors.full_messages.join(', ')}"
    end
  else
    # Создаем новую роль
    if role.save
      puts "  ✨ Создана роль: #{role.name} (ID: #{role.id})"
      created_count += 1
    else
      puts "  ❌ Ошибка создания роли #{role_data[:name]}: #{role.errors.full_messages.join(', ')}"
    end
  end
end

puts "\n📊 Результат:"
puts "  Создано новых ролей: #{created_count}"
puts "  Обновлено существующих ролей: #{updated_count}"
puts "  Всего ролей в системе: #{UserRole.count}"

# Выводим ID ролей для справки
puts "\n📋 ID ролей для справки:"
UserRole.all.each do |role|
  puts "  #{role.name}: ID #{role.id}"
end

puts "✅ Роли пользователей успешно созданы/обновлены!" 