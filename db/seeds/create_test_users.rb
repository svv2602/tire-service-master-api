# Создание тестовых пользователей

# Получение ролей
admin_role = UserRole.find_by(name: 'admin')
manager_role = UserRole.find_by(name: 'manager')
operator_role = UserRole.find_by(name: 'operator')
partner_role = UserRole.find_by(name: 'partner')
client_role = UserRole.find_by(name: 'client')

# Создание администратора, если его еще нет
unless User.exists?(email: 'admin@test.com')
  admin_user = User.create!(
    email: 'admin@test.com',
    password: 'admin123',
    first_name: 'Админ',
    last_name: 'Системы',
    role: admin_role,
    is_active: true,
    email_verified: true
  )
  puts "Создан тестовый администратор: #{admin_user.email} / admin123"
end

# Создание менеджера, если его еще нет
unless User.exists?(email: 'manager@test.com')
  manager_user = User.create!(
    email: 'manager@test.com',
    password: 'manager123',
    first_name: 'Менеджер',
    last_name: 'Системы',
    role: manager_role,
    is_active: true,
    email_verified: true
  )
  puts "Создан тестовый менеджер: #{manager_user.email} / manager123"
end

# Создание оператора, если его еще нет
unless User.exists?(email: 'operator@test.com')
  operator_user = User.create!(
    email: 'operator@test.com',
    password: 'operator123',
    first_name: 'Оператор',
    last_name: 'Системы',
    role: operator_role,
    is_active: true,
    email_verified: true
  )
  
  # Создаем запись оператора с дополнительными данными
  Operator.create!(
    user: operator_user,
    position: 'Старший оператор',
    access_level: 3,
    is_active: true
  )
  
  puts "Создан тестовый оператор: #{operator_user.email} / operator123"
end

# Создание партнера, если его еще нет
unless User.exists?(email: 'partner@test.com')
  partner_user = User.create!(
    email: 'partner@test.com',
    password: 'partner123',
    first_name: 'Партнер',
    last_name: 'Системы',
    role: partner_role,
    is_active: true,
    email_verified: true
  )
  puts "Создан тестовый партнер: #{partner_user.email} / partner123"
end

# Создание клиента, если его еще нет
unless User.exists?(email: 'client@test.com')
  client_user = User.create!(
    email: 'client@test.com',
    password: 'client123',
    first_name: 'Клиент',
    last_name: 'Системы',
    role: client_role,
    is_active: true,
    email_verified: true
  )
  puts "Создан тестовый клиент: #{client_user.email} / client123"
end

puts "Создание тестовых пользователей завершено!" 