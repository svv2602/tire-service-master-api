# db/seeds/partners.rb
# Создание тестовых данных для партнеров

puts 'Creating partners...'

begin
  # Проверяем существование необходимых ролей
  operator_role = UserRole.find_by(name: 'operator')
  manager_role = UserRole.find_by(name: 'manager')
  partner_role = UserRole.find_by(name: 'partner')
  
  unless operator_role
    puts "Creating operator role..."
    operator_role = UserRole.create!(
      name: 'operator',
      description: 'Оператор сервісної точки',
      is_active: true
    )
  end
  
  unless manager_role
    puts "Creating manager role..."
    manager_role = UserRole.create!(
      name: 'manager',
      description: 'Менеджер партнера',
      is_active: true
    )
  end
  
  unless partner_role
    puts "Creating partner role..."
    partner_role = UserRole.create!(
      name: 'partner',
      description: 'Партнер з правами управління своїми сервісними точками',
      is_active: true
    )
  end

  # Получаем регионы и города для партнеров
  kyiv_region = Region.find_or_create_by!(name: "Киевская область", is_active: true)
  kyiv_city = City.find_or_create_by!(name: "Киев", region: kyiv_region, is_active: true)
  
  lviv_region = Region.find_or_create_by!(name: "Львовская область", is_active: true)  
  lviv_city = City.find_or_create_by!(name: "Львов", region: lviv_region, is_active: true)
  
  odesa_region = Region.find_or_create_by!(name: "Одесская область", is_active: true)
  odesa_city = City.find_or_create_by!(name: "Одесса", region: odesa_region, is_active: true)

  partners_data = [
    {
      user: {
        email: 'petrov@shino-express.ua',
        password: 'password123',
        password_confirmation: 'password123',
        first_name: 'Александр',
        last_name: 'Петренко',
        phone: '+380671234567',
        role_id: partner_role.id,
        is_active: true,
        email_verified: true,
        phone_verified: true
      },
      partner: {
        company_name: 'ШиноСервис Экспресс',
        company_description: 'Профессиональный шиномонтаж в центре города',
        contact_person: 'Петренко Александр Иванович',
        legal_address: 'г. Киев, ул. Крещатик, 22',
        tax_number: '12345678901',
        website: 'https://shino-express.ua',
        logo_url: 'https://via.placeholder.com/200x100?text=ШиноСервис',
        is_active: true,
        region_id: kyiv_region.id,
        city_id: kyiv_city.id
      }
    },
    {
      user: {
        email: 'kovalenko@autoshina-plus.ua',
        password: 'password123',
        password_confirmation: 'password123',
        first_name: 'Андрей',
        last_name: 'Коваленко',
        phone: '+380509876543',
        role_id: partner_role.id,
        is_active: true,
        email_verified: true,
        phone_verified: true
      },
      partner: {
        company_name: 'АвтоШина Плюс',
        company_description: 'Широкий ассортимент шин и профессиональный сервис',
        contact_person: 'Коваленко Андрей Петрович',
        legal_address: 'г. Львов, ул. Лычаковская, 45',
        tax_number: '98765432109',
        website: 'https://autoshina-plus.ua',
        logo_url: 'https://via.placeholder.com/200x100?text=АвтоШина',
        is_active: true,
        region_id: lviv_region.id,
        city_id: lviv_city.id
      }
    },
    {
      user: {
        email: 'savchenko@shinmaister.ua',
        password: 'password123',
        password_confirmation: 'password123',
        first_name: 'Ирина',
        last_name: 'Савченко',
        phone: '+380635555555',
        role_id: partner_role.id,
        is_active: true,
        email_verified: true,
        phone_verified: true
      },
      partner: {
        company_name: 'ШинМайстер',
        company_description: 'Мастерская по ремонту и замене шин у моря',
        contact_person: 'Савченко Ирина Олеговна',
        legal_address: 'г. Одесса, ул. Дерибасовская, 12',
        tax_number: '23456789012',
        website: 'https://shinmaister.ua',
        logo_url: 'https://via.placeholder.com/200x100?text=ШинМайстер',
        is_active: true,
        region_id: odesa_region.id,
        city_id: odesa_city.id
      }
    }
  ]

  partners_data.each do |data|
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
    
    # Проверяем, существует ли партнер для этого пользователя
    existing_partner = Partner.find_by(user_id: user.id)
    
    if existing_partner
      puts "  Partner for user #{user.email} already exists, updating..."
      partner = existing_partner
      partner.update!(data[:partner])
    else
      puts "  Creating partner: #{data[:partner][:company_name]}"
      partner = Partner.create!(data[:partner].merge(user_id: user.id))
    end
    
    puts "    ✓ Created/updated partner: #{partner.company_name} (#{user.email})"
  end

  puts "Successfully created/updated #{partners_data.length} partners!"

rescue => e
  puts "Error creating partners: #{e.message}"
  puts e.backtrace
end 