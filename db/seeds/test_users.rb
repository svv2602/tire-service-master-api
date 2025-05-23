# db/seeds/test_users.rb
# Создание тестовых пользователей с простыми учетными данными

puts 'Creating test users...'

begin
  # Проверяем существование таблицы users
  unless ActiveRecord::Base.connection.table_exists?('users')
    puts "Table 'users' does not exist, skipping test_users seed"
    exit
  end

  # Проверяем наличие роли admin
  admin_role = UserRole.find_by(name: 'admin')
  unless admin_role
    puts "Admin role not found, creating..."
    admin_role = UserRole.create!(
      name: 'admin',
      description: 'Адміністратор системи з повними правами',
      is_active: true
    )
  end

  # Создаем тестовых пользователей
  test_users = [
    {
      email: 'admin@example.com',
      password: 'admin123',
      is_active: true,
      first_name: 'Тест',
      last_name: 'Адмін',
      phone: '+380671110000',
      role: admin_role
    },
    {
      email: 'admin@test.com',  # Простой email для тестирования
      password: 'admin',
      is_active: true,
      first_name: 'Простой',
      last_name: 'Админ',
      phone: '+380672220000',
      role: admin_role
    },
    {
      email: 'test@test.com',  # Простой email для тестирования
      password: 'test',
      is_active: true,
      first_name: 'Тестовый',
      last_name: 'Пользователь',
      phone: '+380673330000',
      role: admin_role
    }
  ]

  test_users.each do |user_data|
    # Проверяем существование пользователя
    user = User.find_by(email: user_data[:email])
    
    if user
      puts "  Updating test user: #{user_data[:email]}"
      user.update!(
        password: user_data[:password],
        is_active: true,
        first_name: user_data[:first_name],
        last_name: user_data[:last_name],
        phone: user_data[:phone],
        role: user_data[:role]
      )
    else
      puts "  Creating test user: #{user_data[:email]}"
      user = User.create!(
        email: user_data[:email],
        password: user_data[:password],
        role: user_data[:role],
        is_active: true,
        email_verified: true,
        phone_verified: true,
        first_name: user_data[:first_name],
        last_name: user_data[:last_name],
        phone: user_data[:phone]
      )
    
      # Создаем запись администратора
      admin = Administrator.find_by(user_id: user.id)
      if admin
        admin.update!(access_level: 10)
      else
        Administrator.create!(
          user_id: user.id,
          position: 'Тестовый администратор',
          access_level: 10
        )
      end
    end
  end

  puts "Successfully created test users!"
rescue => e
  puts "Error creating test users: #{e.message}"
  puts e.backtrace
end 