puts '=== Создание тестовых конфигураций шин ==='

# Проверяем наличие брендов и моделей
bmw = CarBrand.find_by(name: 'BMW')
volkswagen = CarBrand.find_by(name: 'Volkswagen')
mercedes = CarBrand.find_by(name: 'Mercedes-Benz')

unless bmw && volkswagen && mercedes
  puts "❌ Не найдены необходимые бренды автомобилей"
  puts "Запустите: rails db:seed SEED=car_brands_and_models_improved"
  exit
end

# BMW модели
bmw_3_series = bmw.car_models.find_or_create_by(name: '3 Series') { |m| m.is_active = true }
bmw_5_series = bmw.car_models.find_or_create_by(name: '5 Series') { |m| m.is_active = true }
bmw_x3 = bmw.car_models.find_or_create_by(name: 'X3') { |m| m.is_active = true }

# Volkswagen модели
vw_tiguan = volkswagen.car_models.find_or_create_by(name: 'Tiguan') { |m| m.is_active = true }
vw_golf = volkswagen.car_models.find_or_create_by(name: 'Golf') { |m| m.is_active = true }

# Mercedes модели
mb_c_class = mercedes.car_models.find_or_create_by(name: 'C-Class') { |m| m.is_active = true }

# Тестовые конфигурации шин
test_configurations = [
  {
    brand: bmw,
    model: bmw_3_series,
    year_from: 2015,
    year_to: 2023,
    tire_sizes: [
      { width: 225, height: 50, diameter: 17, type: 'stock' },
      { width: 225, height: 45, diameter: 18, type: 'optional' },
      { width: 245, height: 40, diameter: 19, type: 'optional' }
    ],
    search_aliases: ['3', '320i', '330i', 'тройка', 'третья серия'],
    search_tokens: 'bmw 3 series 320 330 тройка третья серия'
  },
  {
    brand: bmw,
    model: bmw_5_series,
    year_from: 2016,
    year_to: 2024,
    tire_sizes: [
      { width: 245, height: 45, diameter: 18, type: 'stock' },
      { width: 245, height: 40, diameter: 19, type: 'optional' },
      { width: 275, height: 35, diameter: 20, type: 'optional' }
    ],
    search_aliases: ['5', '520i', '530i', 'пятерка', 'пятая серия'],
    search_tokens: 'bmw 5 series 520 530 пятерка пятая серия'
  },
  {
    brand: bmw,
    model: bmw_x3,
    year_from: 2017,
    year_to: 2024,
    tire_sizes: [
      { width: 245, height: 50, diameter: 19, type: 'stock' },
      { width: 275, height: 40, diameter: 20, type: 'optional' }
    ],
    search_aliases: ['x3', 'икс3', 'x 3'],
    search_tokens: 'bmw x3 икс3 кроссовер'
  },
  {
    brand: volkswagen,
    model: vw_tiguan,
    year_from: 2016,
    year_to: 2024,
    tire_sizes: [
      { width: 215, height: 65, diameter: 17, type: 'stock' },
      { width: 235, height: 55, diameter: 18, type: 'optional' },
      { width: 255, height: 45, diameter: 19, type: 'optional' }
    ],
    search_aliases: ['tiguan', 'тигуан'],
    search_tokens: 'volkswagen tiguan тигуан кроссовер'
  },
  {
    brand: volkswagen,
    model: vw_golf,
    year_from: 2013,
    year_to: 2023,
    tire_sizes: [
      { width: 205, height: 55, diameter: 16, type: 'stock' },
      { width: 225, height: 45, diameter: 17, type: 'optional' },
      { width: 225, height: 40, diameter: 18, type: 'optional' }
    ],
    search_aliases: ['golf', 'гольф'],
    search_tokens: 'volkswagen golf гольф хэтчбек'
  },
  {
    brand: mercedes,
    model: mb_c_class,
    year_from: 2014,
    year_to: 2024,
    tire_sizes: [
      { width: 225, height: 50, diameter: 17, type: 'stock' },
      { width: 245, height: 45, diameter: 18, type: 'optional' },
      { width: 245, height: 40, diameter: 19, type: 'optional' }
    ],
    search_aliases: ['c class', 'c-class', 'с класс', 'c200', 'c220'],
    search_tokens: 'mercedes benz c class с класс c200 c220 седан'
  }
]

# Создаем конфигурации
created_count = 0

test_configurations.each do |config_data|
  config = CarTireConfiguration.find_or_create_by(
    brand: config_data[:brand],
    model: config_data[:model],
    year_from: config_data[:year_from],
    year_to: config_data[:year_to]
  ) do |c|
    c.tire_sizes = config_data[:tire_sizes]
    c.search_aliases = config_data[:search_aliases]
    c.search_tokens = config_data[:search_tokens]
    c.data_version = '2025.1'
    c.source_file = 'seeds/tire_configurations_test.rb'
    c.last_updated = Time.current
    c.is_active = true
    c.is_deprecated = false
  end
  
  if config.persisted?
    created_count += 1
    puts "✓ #{config.full_name} - #{config.tire_sizes.size} размеров шин"
  else
    puts "❌ Ошибка создания конфигурации: #{config.errors.full_messages.join(', ')}"
  end
end

# Обновляем статистику версии
current_version = TireDataVersion.current
if current_version
  stats = current_version.statistics || {}
  stats['brands'] = CarBrand.joins(:car_tire_configurations).distinct.count
  stats['models'] = CarModel.joins(:car_tire_configurations).distinct.count
  stats['configurations'] = CarTireConfiguration.active.not_deprecated.count
  
  current_version.update!(statistics: stats)
  puts "✓ Обновлена статистика версии #{current_version.version}"
end

puts "\n🎯 Создано #{created_count} тестовых конфигураций шин"
puts "📊 Всего конфигураций в системе: #{CarTireConfiguration.active.not_deprecated.count}"

# Примеры поиска для тестирования
puts "\n🔍 Примеры запросов для тестирования:"
puts "- 'BMW 3 Series'"
puts "- 'БМВ тройка'"
puts "- 'Volkswagen Tiguan 2020'"
puts "- 'тигуан резина'"
puts "- 'Mercedes C200'"
puts "- 'шины на 18'"