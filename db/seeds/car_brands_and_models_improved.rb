# db/seeds/car_brands_and_models_improved.rb
# Создание брендов и моделей автомобилей с логотипами

puts '=== Создание брендов и моделей автомобилей ==='

# Данные брендов с логотипами
brands_data = [
  {
    name: 'Toyota',
    country: 'Japan',
    logo_url: 'https://logos-world.net/wp-content/uploads/2020/04/Toyota-Logo.png',
    models: ['Camry', 'Corolla', 'RAV4', 'Land Cruiser', 'Prius', 'Highlander', 'Sienna']
  },
  {
    name: 'Honda',
    country: 'Japan',
    logo_url: 'https://logos-world.net/wp-content/uploads/2020/04/Honda-Logo.png',
    models: ['Civic', 'Accord', 'CR-V', 'Pilot', 'HR-V', 'Fit', 'Ridgeline']
  },
  {
    name: 'Volkswagen',
    country: 'Germany',
    logo_url: 'https://logos-world.net/wp-content/uploads/2020/04/Volkswagen-Logo.png',
    models: ['Golf', 'Passat', 'Tiguan', 'Polo', 'Touareg', 'Jetta', 'Atlas']
  },
  {
    name: 'BMW',
    country: 'Germany',
    logo_url: 'https://logos-world.net/wp-content/uploads/2020/04/BMW-Logo.png',
    models: ['3 Series', '5 Series', 'X3', 'X5', '7 Series', 'X1', 'X7']
  },
  {
    name: 'Mercedes-Benz',
    country: 'Germany',
    logo_url: 'https://logos-world.net/wp-content/uploads/2020/04/Mercedes-Benz-Logo.png',
    models: ['C-Class', 'E-Class', 'GLC', 'S-Class', 'GLE', 'A-Class', 'GLS']
  },
  {
    name: 'Audi',
    country: 'Germany',
    logo_url: 'https://logos-world.net/wp-content/uploads/2020/04/Audi-Logo.png',
    models: ['A3', 'A4', 'A6', 'Q5', 'Q7', 'A8', 'Q3']
  },
  {
    name: 'Ford',
    country: 'USA',
    logo_url: 'https://logos-world.net/wp-content/uploads/2020/04/Ford-Logo.png',
    models: ['Focus', 'Mondeo', 'Kuga', 'Explorer', 'Mustang', 'F-150', 'Edge']
  },
  {
    name: 'Hyundai',
    country: 'South Korea',
    logo_url: 'https://logos-world.net/wp-content/uploads/2020/04/Hyundai-Logo.png',
    models: ['Elantra', 'Sonata', 'Tucson', 'Santa Fe', 'i30', 'Accent', 'Palisade']
  },
  {
    name: 'Nissan',
    country: 'Japan',
    logo_url: 'https://logos-world.net/wp-content/uploads/2020/04/Nissan-Logo.png',
    models: ['Altima', 'Sentra', 'Rogue', 'Pathfinder', 'Murano', 'Maxima', 'Armada']
  },
  {
    name: 'Kia',
    country: 'South Korea',
    logo_url: 'https://logos-world.net/wp-content/uploads/2020/04/Kia-Logo.png',
    models: ['Optima', 'Forte', 'Sportage', 'Sorento', 'Soul', 'Stinger', 'Telluride']
  }
]

created_brands = 0
updated_brands = 0
created_models = 0
updated_models = 0

brands_data.each do |brand_data|
  puts "  🚗 Обработка бренда: #{brand_data[:name]}"
  
  # Ищем или создаем бренд
  brand = CarBrand.find_by(name: brand_data[:name])
  
  if brand
    # Обновляем существующий бренд
    brand.update!(
      is_active: true
    )
    updated_brands += 1
    puts "    ✏️  Обновлен бренд: #{brand.name}"
  else
    # Создаем новый бренд
    brand = CarBrand.create!(
      name: brand_data[:name],
      is_active: true
    )
    created_brands += 1
    puts "    ✨ Создан бренд: #{brand.name}"
  end

  # Обрабатываем модели
  brand_data[:models].each do |model_name|
    existing_model = brand.car_models.find_by(name: model_name)
    
    if existing_model
      # Обновляем существующую модель
      existing_model.update!(is_active: true)
      updated_models += 1
      puts "      ✏️  Обновлена модель: #{model_name}"
    else
      # Создаем новую модель
      brand.car_models.create!(
        name: model_name,
        is_active: true
      )
      created_models += 1
      puts "      ✨ Создана модель: #{model_name}"
    end
  end
end

puts ""
puts "📊 Результат:"
puts "  Создано новых брендов: #{created_brands}"
puts "  Обновлено существующих брендов: #{updated_brands}"
puts "  Создано новых моделей: #{created_models}"
puts "  Обновлено существующих моделей: #{updated_models}"
puts "  Всего брендов в системе: #{CarBrand.count}"
puts "  Всего моделей в системе: #{CarModel.count}"

# Статистика по брендам
puts ""
puts "📈 Модели по брендам:"
CarBrand.includes(:car_models).each do |brand|
  models_count = brand.car_models.count
  puts "  #{brand.name}: #{models_count} моделей"
end

puts ""
puts "✅ Бренды и модели автомобилей успешно созданы/обновлены!" 