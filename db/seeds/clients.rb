# db/seeds/clients.rb
# Створення тестових даних для клієнтів

puts 'Creating clients...'

begin
  # Получаем роль клиента
  client_role = UserRole.find_by(name: 'client')
  unless client_role
    puts "Client role not found, creating..."
    client_role = UserRole.create!(
      name: 'client',
      description: 'Клієнт системи',
      is_active: true
    )
  end

  # Дані клієнтів
  clients_data = [
    {
      user: {
        first_name: 'Олександр',
        last_name: 'Шевченко',
        email: 'o.shevchenko@gmail.com',
        phone: '+380671112233',
        password: 'password123',
        password_confirmation: 'password123',
        role_id: client_role.id,
        is_active: true,
        email_verified: true,
        phone_verified: true
      },
      client: {
        preferred_notification_method: 'email'
      },
      registration_date: Date.today - 86.days
    },
    {
      user: {
        first_name: 'Марія',
        last_name: 'Коваленко',
        email: 'mariya.k@ukr.net',
        phone: '+380502223344',
        password: 'password123',
        password_confirmation: 'password123',
        role_id: client_role.id,
        is_active: true,
        email_verified: true,
        phone_verified: true
      },
      client: {
        preferred_notification_method: 'sms'
      },
      registration_date: Date.today - 72.days
    },
    {
      user: {
        first_name: 'Андрій',
        last_name: 'Мельник',
        email: 'a.melnyk@gmail.com',
        phone: '+380633334455',
        password: 'password123',
        password_confirmation: 'password123',
        role_id: client_role.id,
        is_active: true,
        email_verified: true,
        phone_verified: true
      },
      client: {
        preferred_notification_method: 'push'
      },
      registration_date: Date.today - 65.days
    },
    {
      user: {
        first_name: 'Ірина',
        last_name: 'Бондаренко',
        email: 'iryna.b@ukr.net',
        phone: '+380964445566',
        password: 'password123',
        password_confirmation: 'password123',
        role_id: client_role.id,
        is_active: true,
        email_verified: true,
        phone_verified: true
      },
      client: {
        preferred_notification_method: 'email'
      },
      registration_date: Date.today - 48.days
    },
    {
      user: {
        first_name: 'Василь',
        last_name: 'Петренко',
        email: 'vasyl.p@gmail.com',
        phone: '+380675556677',
        password: 'password123',
        password_confirmation: 'password123',
        role_id: client_role.id,
        is_active: true,
        email_verified: false,
        phone_verified: false
      },
      client: {
        preferred_notification_method: 'sms'
      },
      registration_date: Date.today - 31.days
    },
    {
      user: {
        first_name: 'Наталія',
        last_name: 'Савченко',
        email: 'nataliya.s@ukr.net',
        phone: '+380506667788',
        password: 'password123',
        password_confirmation: 'password123',
        role_id: client_role.id,
        is_active: true,
        email_verified: true,
        phone_verified: true
      },
      client: {
        preferred_notification_method: 'email'
      },
      registration_date: Date.today - 27.days
    },
    {
      user: {
        first_name: 'Сергій',
        last_name: 'Кравченко',
        email: 's.kravchenko@gmail.com',
        phone: '+380637778899',
        password: 'password123',
        password_confirmation: 'password123',
        role_id: client_role.id,
        is_active: true,
        email_verified: true,
        phone_verified: true
      },
      client: {
        preferred_notification_method: 'push'
      },
      registration_date: Date.today - 15.days
    },
    {
      user: {
        first_name: 'Тетяна',
        last_name: 'Лисенко',
        email: 'tetiana.l@ukr.net',
        phone: '+380968889900',
        password: 'password123',
        password_confirmation: 'password123',
        role_id: client_role.id,
        is_active: true,
        email_verified: false,
        phone_verified: true
      },
      client: {
        preferred_notification_method: 'sms'
      },
      registration_date: Date.today - 8.days
    },
    {
      user: {
        first_name: 'Олег',
        last_name: 'Іваненко',
        email: 'oleg.i@gmail.com',
        phone: '+380679990011',
        password: 'password123',
        password_confirmation: 'password123',
        role_id: client_role.id,
        is_active: true,
        email_verified: true,
        phone_verified: true
      },
      client: {
        preferred_notification_method: 'email'
      },
      registration_date: Date.today - 3.days
    },
    {
      user: {
        first_name: 'Юлія',
        last_name: 'Михайленко',
        email: 'yuliya.m@ukr.net',
        phone: '+380500001122',
        password: 'password123',
        password_confirmation: 'password123',
        role_id: client_role.id,
        is_active: true,
        email_verified: false,
        phone_verified: false
      },
      client: {
        preferred_notification_method: 'push'
      },
      registration_date: Date.today - 1.days
    }
  ]

  # Створення клієнтів і автомобілів
  clients_data.each do |data|
    # Проверяем, существует ли пользователь с таким email
    existing_user = User.find_by(email: data[:user][:email])
    
    if existing_user
      puts "  User with email #{data[:user][:email]} already exists, updating..."
      user = existing_user
      user.update!(data[:user].except(:email))
    else
      puts "  Creating user: #{data[:user][:email]}"
      user = User.create!(data[:user])
    end
    
    # Проверяем, существует ли клиент для этого пользователя
    existing_client = Client.find_by(user_id: user.id)
    
    if existing_client
      puts "  Client for user #{user.email} already exists, updating..."
      client = existing_client
      client.update!(data[:client])
    else
      puts "  Creating client: #{user.first_name} #{user.last_name}"
      client = Client.create!(data[:client].merge(user_id: user.id))
    end
    
    # Додавання випадкової кількості автомобілів для клієнта (1-3)
    if client.cars.empty?
      car_count = rand(1..3)
      
      # Получаем все бренды и модели из базы
      available_brands = CarBrand.all.to_a
      
      car_count.times do |i|
        # Выбираем случайный бренд
        brand = available_brands.sample
        
        # Пропускаем, если бренд не найден
        next unless brand
        
        # Получаем модели для этого бренда
        models = CarModel.where(brand_id: brand.id).to_a
        
        # Выбираем случайную модель из этого бренда
        model = models.sample
        
        # Если модель не найдена, пропускаем создание автомобиля
        next unless model
        
        # Получаем случайный тип автомобиля
        car_type = CarType.all.sample
        next unless car_type
        
        year = rand(2010..2023)
        
        # Генерація українського номерного знаку
        regions = ['AA', 'AB', 'AC', 'AE', 'AH', 'AI', 'AK', 'AM', 'AO', 'AP', 'AT', 'AX', 'BA', 'BB', 'BC', 'BE', 'BH']
        plate_region = regions.sample
        plate_numbers = sprintf('%04d', rand(1..9999))
        plate_suffix = ('A'..'Z').to_a.sample(2).join
        plate = "#{plate_region} #{plate_numbers} #{plate_suffix}"
        
        client.cars.create!({
          brand_id: brand.id,
          model_id: model.id,
          year: year,
          license_plate: plate,
          tire_size: ['205/55 R16', '195/65 R15', '225/45 R17', '215/60 R16', '235/55 R18'].sample,
          car_type_id: car_type.id, # Используем ID найденного типа автомобиля
          is_primary: (i == 0) # Первый автомобиль будет основным
        })
      end
    end
    
    puts "  Created/updated client: #{client.user.first_name} #{client.user.last_name} with #{client.cars.count} cars"
  end

  puts "Created/updated #{clients_data.length} clients with #{ClientCar.count} cars successfully!"

rescue => e
  puts "Error creating clients: #{e.message}"
  puts e.backtrace
end 