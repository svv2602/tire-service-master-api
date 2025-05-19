# db/seeds/clients.rb
# Створення тестових даних для клієнтів

puts 'Creating clients...'

# Очищення існуючих записів
Client.destroy_all

# Дані клієнтів
clients_data = [
  {
    first_name: 'Олександр',
    last_name: 'Шевченко',
    email: 'o.shevchenko@gmail.com',
    phone: '+380 67 111 22 33',
    verified: true,
    registration_date: Date.today - 86.days
  },
  {
    first_name: 'Марія',
    last_name: 'Коваленко',
    email: 'mariya.k@ukr.net',
    phone: '+380 50 222 33 44',
    verified: true,
    registration_date: Date.today - 72.days
  },
  {
    first_name: 'Андрій',
    last_name: 'Мельник',
    email: 'a.melnyk@gmail.com',
    phone: '+380 63 333 44 55',
    verified: true,
    registration_date: Date.today - 65.days
  },
  {
    first_name: 'Ірина',
    last_name: 'Бондаренко',
    email: 'iryna.b@ukr.net',
    phone: '+380 96 444 55 66',
    verified: true,
    registration_date: Date.today - 48.days
  },
  {
    first_name: 'Василь',
    last_name: 'Петренко',
    email: 'vasyl.p@gmail.com',
    phone: '+380 67 555 66 77',
    verified: false,
    registration_date: Date.today - 31.days
  },
  {
    first_name: 'Наталія',
    last_name: 'Савченко',
    email: 'nataliya.s@ukr.net',
    phone: '+380 50 666 77 88',
    verified: true,
    registration_date: Date.today - 27.days
  },
  {
    first_name: 'Сергій',
    last_name: 'Кравченко',
    email: 's.kravchenko@gmail.com',
    phone: '+380 63 777 88 99',
    verified: true,
    registration_date: Date.today - 15.days
  },
  {
    first_name: 'Тетяна',
    last_name: 'Лисенко',
    email: 'tetiana.l@ukr.net',
    phone: '+380 96 888 99 00',
    verified: false,
    registration_date: Date.today - 8.days
  },
  {
    first_name: 'Олег',
    last_name: 'Іваненко',
    email: 'oleg.i@gmail.com',
    phone: '+380 67 999 00 11',
    verified: true,
    registration_date: Date.today - 3.days
  },
  {
    first_name: 'Юлія',
    last_name: 'Михайленко',
    email: 'yuliya.m@ukr.net',
    phone: '+380 50 000 11 22',
    verified: false,
    registration_date: Date.today - 1.days
  }
]

# Додавання автомобілів клієнтів
car_brands = ['Volkswagen', 'Renault', 'Škoda', 'Toyota', 'Hyundai', 'Kia', 'Ford', 'BMW', 'Audi', 'Nissan']
car_models = {
  'Volkswagen' => ['Golf', 'Passat', 'Tiguan', 'Polo'],
  'Renault' => ['Logan', 'Duster', 'Sandero', 'Megane'],
  'Škoda' => ['Octavia', 'Fabia', 'Superb', 'Kodiaq'],
  'Toyota' => ['Corolla', 'Camry', 'RAV4', 'Yaris'],
  'Hyundai' => ['Tucson', 'Elantra', 'i30', 'Kona'],
  'Kia' => ['Sportage', 'Ceed', 'Rio', 'Sorento'],
  'Ford' => ['Focus', 'Fiesta', 'Kuga', 'Mondeo'],
  'BMW' => ['3 Series', '5 Series', 'X5', 'X3'],
  'Audi' => ['A4', 'A6', 'Q5', 'A3'],
  'Nissan' => ['Qashqai', 'X-Trail', 'Juke', 'Leaf']
}

# Створення клієнтів і автомобілів
clients_data.each do |client_data|
  client = Client.create!(client_data)
  
  # Додавання випадкової кількості автомобілів для клієнта (1-3)
  car_count = rand(1..3)
  
  car_count.times do
    brand = car_brands.sample
    model = car_models[brand].sample
    year = rand(2010..2023)
    
    # Генерація українського номерного знаку
    regions = ['AA', 'AB', 'AC', 'AE', 'AH', 'AI', 'AK', 'AM', 'AO', 'AP', 'AT', 'AX', 'BA', 'BB', 'BC', 'BE', 'BH']
    plate_region = regions.sample
    plate_numbers = sprintf('%04d', rand(1..9999))
    plate_suffix = ('A'..'Z').to_a.sample(2).join
    plate = "#{plate_region} #{plate_numbers} #{plate_suffix}"
    
    client.cars.create!({
      brand: brand,
      model: model,
      year: year,
      license_plate: plate,
      vin: "WVWZZZ#{rand(10..99)}ZZZ#{rand(100000..999999)}",
      tire_size: ['205/55 R16', '195/65 R15', '225/45 R17', '215/60 R16', '235/55 R18'].sample,
      car_type_id: rand(1..6) # Використовуємо випадковий тип автомобіля
    })
  end
  
  puts "  Created client: #{client.first_name} #{client.last_name} with #{client.cars.count} cars"
end

puts "Created #{Client.count} clients with #{Car.count} cars successfully!" 