# db/seeds/users.rb
# Створення тестових даних для користувачів

puts 'Creating users...'

# Нам потрібні ролі користувачів
if UserRole.count == 0
  puts "  No user roles found, please run user_roles seed first"
  exit
end

# Очищення існуючих записів (якщо потрібно перезаписати)
# User.destroy_all 

# Знаходимо ID ролей
admin_role_id = UserRole.find_by(name: 'admin')&.id
manager_role_id = UserRole.find_by(name: 'manager')&.id
operator_role_id = UserRole.find_by(name: 'operator')&.id
client_role_id = UserRole.find_by(name: 'client')&.id

# Базовий пароль для тестових користувачів
default_password = 'password123'

# Создаем роли пользователей
admin_role = UserRole.find_by(name: 'admin')
partner_role = UserRole.find_by(name: 'partner')
manager_role = UserRole.find_by(name: 'manager')
client_role = UserRole.find_by(name: 'client')
operator_role = UserRole.find_by(name: 'operator')

# Проверяем, что роли найдены, иначе создаем их
if admin_role.nil?
  admin_role = UserRole.create!(name: 'admin', description: 'Администратор системы')
end

if partner_role.nil?
  partner_role = UserRole.create!(name: 'partner', description: 'Партнер')
end

if manager_role.nil?
  manager_role = UserRole.create!(name: 'manager', description: 'Менеджер')
end

if client_role.nil?
  client_role = UserRole.create!(name: 'client', description: 'Клиент')
end

if operator_role.nil?
  operator_role = UserRole.create!(name: 'operator', description: 'Оператор')
end

# Получаем ID ролей
admin_role_id = admin_role.id
partner_role_id = partner_role.id
manager_role_id = manager_role.id
client_role_id = client_role.id
operator_role_id = operator_role.id

# Создаем тестовых пользователей
admin_user = User.find_or_initialize_by(email: 'admin@test.com')
admin_user.assign_attributes(
  password: 'password123',
  first_name: 'Admin',
  last_name: 'Test',
  role: admin_role,
  is_active: true
)
admin_user.save!
puts "Admin user created: #{admin_user.email}"

partner_user = User.find_or_initialize_by(email: 'partner@test.com')
partner_user.assign_attributes(
  password: 'password123',
  first_name: 'Partner',
  last_name: 'Test',
  role: partner_role,
  is_active: true
)
partner_user.save!
puts "Partner user created: #{partner_user.email}"

manager_user = User.find_or_initialize_by(email: 'manager@test.com')
manager_user.assign_attributes(
  password: 'password123',
  first_name: 'Manager',
  last_name: 'Test',
  role: manager_role,
  is_active: true
)
manager_user.save!
puts "Manager user created: #{manager_user.email}"

client_user = User.find_or_initialize_by(email: 'client@test.com')
client_user.assign_attributes(
  password: 'password123',
  first_name: 'Client',
  last_name: 'Test',
  role: client_role,
  is_active: true
)
client_user.save!
puts "Client user created: #{client_user.email}"

# Создаем клиента для пользователя с ролью client
client = Client.find_or_initialize_by(user_id: client_user.id)
client.save!
puts "Client record created for user: #{client_user.email}"

# Дані користувачів
users_data = [
  # Адміністратори
  {
    email: 'admin@tireservice.ua',
    phone: '+380 67 000 00 00',
    password: default_password,
    first_name: 'Головний',
    last_name: 'Адміністратор',
    role_id: admin_role_id,
    is_active: true,
    email_verified: true,
    phone_verified: true
  },
  # Простий адмін для тестування
  {
    email: 'admin@example.com',
    phone: '+380 67 111 00 00',
    password: 'admin123',
    first_name: 'Тест',
    last_name: 'Адмін',
    role_id: admin_role_id,
    is_active: true,
    email_verified: true,
    phone_verified: true
  },
  # Ще один простий адмін
  {
    email: 'admin123@example.com',  # Исправлен невалидный email 'admin' на валидный
    phone: '+380 67 222 11 22',  # Изменен номер телефона, чтобы избежать дублирования
    password: 'admin123',  # Пароль достаточной длины (минимум 6 символов)
    first_name: 'Простий',
    last_name: 'Адмін',
    role_id: admin_role_id,
    is_active: true,
    email_verified: true,
    phone_verified: true
  },
  
  # Менеджери
  {
    email: 'manager@shino-express.ua',
    phone: '+380 67 123 45 60',
    password: default_password,
    first_name: 'Олександр',
    last_name: 'Петренко',
    role_id: manager_role_id,
    is_active: true,
    email_verified: true,
    phone_verified: true
  },
  {
    email: 'manager@autoshina-plus.ua',
    phone: '+380 50 987 65 40',
    password: default_password,
    first_name: 'Андрій',
    last_name: 'Коваленко',
    role_id: manager_role_id,
    is_active: true,
    email_verified: true,
    phone_verified: true
  },
  
  # Оператори
  {
    email: 'operator1@shino-express.ua',
    phone: '+380 67 111 11 11',
    password: default_password,
    first_name: 'Василь',
    last_name: 'Іваненко',
    role_id: operator_role_id,
    is_active: true,
    email_verified: true,
    phone_verified: true
  },
  {
    email: 'operator2@shino-express.ua',
    phone: '+380 67 222 22 22',
    password: default_password,
    first_name: 'Марія',
    last_name: 'Ковальчук',
    role_id: operator_role_id,
    is_active: true,
    email_verified: true,
    phone_verified: true
  },
  
  # Клієнти (додаткові до тих, що вже можуть існувати)
  {
    email: 'client1@gmail.com',
    phone: '+380 67 333 33 33',
    password: default_password,
    first_name: 'Іван',
    last_name: 'Франко',
    role_id: client_role_id,
    is_active: true,
    email_verified: true,
    phone_verified: true
  },
  {
    email: 'client2@ukr.net',
    phone: '+380 67 444 44 44',
    password: default_password,
    first_name: 'Леся',
    last_name: 'Українка',
    role_id: client_role_id,
    is_active: true,
    email_verified: true,
    phone_verified: true
  }
]

# Створення користувачів і налаштування їх ролей
users_data.each do |user_data|
  # Перевіримо чи існує користувач з таким email
  existing_user = User.find_by(email: user_data[:email])
  
  if existing_user
    puts "  User with email #{user_data[:email]} already exists, updating"
    existing_user.update!(user_data)
    user = existing_user
  else
    # Створюємо користувача
    user = User.create!(user_data)
    puts "  Created new user: #{user.email}"
  end
  
  # В залежності від ролі створюємо відповідний запис
  case user.role_id
  when admin_role_id
    admin = Administrator.find_by(user_id: user.id)
    if admin
      admin.update!(
        position: 'Головний адміністратор',
        access_level: 10
      )
      puts "  Updated administrator: #{user.first_name} #{user.last_name}"
    else
      Administrator.create!(
        user_id: user.id,
        position: 'Головний адміністратор',
        access_level: 10
      )
      puts "  Created administrator: #{user.first_name} #{user.last_name}"
    end
    
  when manager_role_id
    # Знаходимо партнера за доменом email
    domain = user.email.split('@').last
    # Ищем партнера по компании, а не по email
    partner = Partner.joins(:user).where("users.email LIKE ?", "%#{domain}").first
    
    if partner
      manager = Manager.find_by(user_id: user.id)
      if manager
        manager.update!(
          partner_id: partner.id,
          position: 'Керівник відділення',
          access_level: 5
        )
        puts "  Updated manager: #{user.first_name} #{user.last_name} for partner #{partner.company_name}"
      else
        manager = Manager.create!(
          user_id: user.id,
          partner_id: partner.id,
          position: 'Керівник відділення',
          access_level: 5
        )
        
        # Додаємо всі сервісні точки партнера до менеджера
        ServicePoint.where(partner_id: partner.id).each do |point|
          unless ManagerServicePoint.find_by(manager_id: manager.id, service_point_id: point.id)
            ManagerServicePoint.create!(
              manager_id: manager.id,
              service_point_id: point.id
            )
          end
        end
        
        puts "  Created manager: #{user.first_name} #{user.last_name} for partner #{partner.company_name}"
      end
    else
      puts "  Warning: No partner found for email domain #{domain}, skipping manager association"
    end
    
  when client_role_id
    client = Client.find_by(user_id: user.id)
    if client
      client.update!(
        preferred_notification_method: 'email',
        marketing_consent: [true, false].sample
      )
      puts "  Updated client: #{user.first_name} #{user.last_name}"
    else
      Client.create!(
        user_id: user.id,
        preferred_notification_method: 'email',
        marketing_consent: [true, false].sample
      )
      puts "  Created client: #{user.first_name} #{user.last_name}"
    end
  end
end

puts "Created users successfully!" 