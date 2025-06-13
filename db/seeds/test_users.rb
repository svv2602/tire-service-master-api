# db/seeds/test_users.rb
# Создание тестовых пользователей с простыми учетными данными

puts 'Creating test users...'

begin
  # Проверяем существование таблицы users
  unless ActiveRecord::Base.connection.table_exists?('users')
    puts "Table 'users' does not exist, skipping test_users seed"
    exit
  end

  # Получаем все роли
  admin_role = UserRole.find_by(name: 'admin')
  manager_role = UserRole.find_by(name: 'manager')
  operator_role = UserRole.find_by(name: 'operator')
  partner_role = UserRole.find_by(name: 'partner')
  client_role = UserRole.find_by(name: 'client')

  unless admin_role
    puts "Admin role not found, creating..."
    admin_role = UserRole.create!(
      name: 'admin',
      description: 'Адміністратор системи з повними правами',
      is_active: true
    )
  end

  # Создаем тестовых пользователей с разными ролями
  test_users = [
    {
      email: 'admin@example.com',
      password: 'admin123',
      password_confirmation: 'admin123',
      is_active: true,
      first_name: 'Системный',
      last_name: 'Администратор',
      phone: '+380671110000',
      role_id: admin_role.id,
      email_verified: true,
      phone_verified: true
    },
    {
      email: 'admin@test.com',  # Основной тестовый пользователь
      password: 'admin123',
      password_confirmation: 'admin123',
      is_active: true,
      first_name: 'Тестовый',
      last_name: 'Админ',
      phone: '+380672220000',
      role_id: admin_role.id,
      email_verified: true,
      phone_verified: true
    },
    {
      email: 'test@test.com',  # Простой тестовый пользователь
      password: 'test123',
      password_confirmation: 'test123',
      is_active: true,
      first_name: 'Тестовый',
      last_name: 'Пользователь',
      phone: '+380673330000',
      role_id: admin_role.id,
      email_verified: true,
      phone_verified: true
    },
    {
      email: 'manager@test.com',  # Тестовый менеджер
      password: 'manager123',
      password_confirmation: 'manager123',
      is_active: true,
      first_name: 'Тестовый',
      last_name: 'Менеджер',
      phone: '+380674440000',
      role_id: manager_role&.id || admin_role.id,
      email_verified: true,
      phone_verified: true
    },
    {
      email: 'operator@test.com',  # Тестовый оператор
      password: 'operator123',
      password_confirmation: 'operator123',
      is_active: true,
      first_name: 'Тестовый',
      last_name: 'Оператор',
      phone: '+380675550000',
      role_id: operator_role&.id || admin_role.id,
      email_verified: true,
      phone_verified: true
    },
    {
      email: 'partner@test.com',  # Тестовый партнер
      password: 'partner123',
      password_confirmation: 'partner123',
      is_active: true,
      first_name: 'Тестовый',
      last_name: 'Партнер',
      phone: '+380677770000',
      role_id: partner_role&.id || admin_role.id,
      email_verified: true,
      phone_verified: true
    },
    {
      email: 'client@test.com',  # Тестовый клиент
      password: 'client123',
      password_confirmation: 'client123',
      is_active: true,
      first_name: 'Тестовый',
      last_name: 'Клиент',
      phone: '+380676660000',
      role_id: client_role&.id || admin_role.id,
      email_verified: true,
      phone_verified: true
    }
  ]

  test_users.each do |user_data|
    # Проверяем существование пользователя
    user = User.find_by(email: user_data[:email])
    
    if user
      puts "  Updating test user: #{user_data[:email]}"
      # Обновляем существующего пользователя
      user.password = user_data[:password]
      user.password_confirmation = user_data[:password_confirmation]
      user.is_active = user_data[:is_active]
      user.first_name = user_data[:first_name]
      user.last_name = user_data[:last_name]
      user.phone = user_data[:phone]
      user.role_id = user_data[:role_id]
      user.email_verified = user_data[:email_verified]
      user.phone_verified = user_data[:phone_verified]
      user.save!
      puts "    ✓ Updated user: #{user.email}"
    else
      puts "  Creating test user: #{user_data[:email]}"
      user = User.create!(user_data)
      puts "    ✓ Created user: #{user.email} with role: #{user.role&.name}"
    end

    # Создаем запись администратора для админов
    if user.role&.name == 'admin'
      admin = Administrator.find_by(user_id: user.id)
      unless admin
        Administrator.create!(
          user_id: user.id,
          position: 'Тестовый администратор',
          access_level: 10
        )
        puts "    ✓ Created administrator profile for #{user.email}"
      end
    end

    # Создаем клиента для тестового клиента
    if user.role&.name == 'client'
      client = Client.find_by(user_id: user.id)
      unless client
        Client.create!(
          user_id: user.id,
          preferred_notification_method: 'email'
        )
        puts "    ✓ Created client profile for #{user.email}"
      end
    end
    
    # Создаем оператора для тестового оператора
    if user.role&.name == 'operator'
      operator = Operator.find_by(user_id: user.id)
      unless operator
        Operator.create!(
          user_id: user.id,
          position: 'Тестовый оператор',
          access_level: 3,
          is_active: true
        )
        puts "    ✓ Created operator profile for #{user.email}"
      end
    end
  end

  puts "Successfully created/updated #{test_users.length} test users!"
  puts ""
  puts "=== ТЕСТОВЫЕ УЧЕТНЫЕ ДАННЫЕ ДЛЯ ВХОДА ==="
  puts "Админ:    admin@test.com / admin123"  
  puts "Менеджер: manager@test.com / manager123"
  puts "Оператор: operator@test.com / operator123"
  puts "Партнер:  partner@test.com / partner123"
  puts "Клиент:   client@test.com / client123"
  puts "=========================================="

rescue => e
  puts "Error creating test users: #{e.message}"
  puts e.backtrace
end 