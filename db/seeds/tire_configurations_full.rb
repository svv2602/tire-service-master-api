# Полные конфигурации шин для системы поиска
# Источник: агрегированные данные из CSV файлов с реальными размерами шин

puts "🔍 Создание полных конфигураций шин для поиска..."

# Получаем существующие бренды и модели
brands = CarBrand.all.index_by(&:name)
models = CarModel.joins(:car_brand).select('car_models.*, car_brands.name as brand_name').index_by { |m| "#{m.brand_name}|#{m.name}" }

# Текущая версия данных
current_version = "1.0.#{Time.current.strftime('%Y%m%d')}"

# Полные конфигурации с реальными размерами шин
configurations_data = [
  # BMW 3 Series - популярные размеры
  {
    brand: 'BMW', model: '3 Series',
    year_from: 2012, year_to: 2023,
    tire_sizes: [
      { width: 225, height: 50, diameter: 17, type: 'stock' },
      { width: 225, height: 45, diameter: 18, type: 'stock' },
      { width: 255, height: 40, diameter: 18, type: 'optional' },
      { width: 225, height: 40, diameter: 19, type: 'optional' },
      { width: 255, height: 35, diameter: 19, type: 'optional' }
    ],
    search_aliases: ['БМВ 3 серия', 'бмв тройка', 'BMW 320i', 'BMW 330i', 'BMW 335i'],
    search_tokens: 'BMW 3 Series БМВ тройка 320i 330i 335i третья серия'
  },
  
  # BMW 5 Series
  {
    brand: 'BMW', model: '5 Series',
    year_from: 2010, year_to: 2023,
    tire_sizes: [
      { width: 245, height: 50, diameter: 18, type: 'stock' },
      { width: 275, height: 40, diameter: 19, type: 'stock' },
      { width: 245, height: 45, diameter: 19, type: 'optional' },
      { width: 275, height: 35, diameter: 20, type: 'optional' }
    ],
    search_aliases: ['БМВ 5 серия', 'бмв пятерка', 'BMW 520i', 'BMW 530i', 'BMW 540i'],
    search_tokens: 'BMW 5 Series БМВ пятерка 520i 530i 540i пятая серия'
  },
  
  # BMW X3
  {
    brand: 'BMW', model: 'X3',
    year_from: 2011, year_to: 2023,
    tire_sizes: [
      { width: 245, height: 50, diameter: 19, type: 'stock' },
      { width: 275, height: 40, diameter: 20, type: 'stock' },
      { width: 245, height: 45, diameter: 20, type: 'optional' },
      { width: 285, height: 35, diameter: 21, type: 'optional' }
    ],
    search_aliases: ['БМВ Х3', 'бмв икс3', 'BMW X3'],
    search_tokens: 'BMW X3 БМВ икс3 кроссовер внедорожник'
  },
  
  # BMW X5
  {
    brand: 'BMW', model: 'X5',
    year_from: 2007, year_to: 2023,
    tire_sizes: [
      { width: 255, height: 50, diameter: 19, type: 'stock' },
      { width: 275, height: 40, diameter: 20, type: 'stock' },
      { width: 315, height: 35, diameter: 20, type: 'optional' },
      { width: 275, height: 35, diameter: 21, type: 'optional' },
      { width: 315, height: 30, diameter: 22, type: 'optional' }
    ],
    search_aliases: ['БМВ Х5', 'бмв икс5', 'BMW X5'],
    search_tokens: 'BMW X5 БМВ икс5 кроссовер внедорожник большой'
  },
  
  # Mercedes-Benz C-Class
  {
    brand: 'Mercedes-Benz', model: 'C-Class',
    year_from: 2008, year_to: 2023,
    tire_sizes: [
      { width: 225, height: 50, diameter: 17, type: 'stock' },
      { width: 225, height: 45, diameter: 18, type: 'stock' },
      { width: 255, height: 40, diameter: 18, type: 'optional' },
      { width: 225, height: 40, diameter: 19, type: 'optional' }
    ],
    search_aliases: ['Мерседес С-класс', 'мерседес с класс', 'C200', 'C220', 'C300'],
    search_tokens: 'Mercedes C-Class мерседес с класс C200 C220 C300'
  },
  
  # Mercedes-Benz E-Class
  {
    brand: 'Mercedes-Benz', model: 'E-Class',
    year_from: 2009, year_to: 2023,
    tire_sizes: [
      { width: 245, height: 45, diameter: 18, type: 'stock' },
      { width: 245, height: 40, diameter: 19, type: 'stock' },
      { width: 275, height: 35, diameter: 19, type: 'optional' },
      { width: 255, height: 35, diameter: 20, type: 'optional' }
    ],
    search_aliases: ['Мерседес Е-класс', 'мерседес е класс', 'E200', 'E220', 'E300'],
    search_tokens: 'Mercedes E-Class мерседес е класс E200 E220 E300'
  },
  
  # Audi A4
  {
    brand: 'Audi', model: 'A4',
    year_from: 2008, year_to: 2023,
    tire_sizes: [
      { width: 225, height: 50, diameter: 17, type: 'stock' },
      { width: 245, height: 45, diameter: 18, type: 'stock' },
      { width: 245, height: 40, diameter: 19, type: 'optional' },
      { width: 255, height: 35, diameter: 19, type: 'optional' }
    ],
    search_aliases: ['Ауди А4', 'ауди а4', 'Audi A4'],
    search_tokens: 'Audi A4 ауди а4 седан универсал'
  },
  
  # Audi Q5
  {
    brand: 'Audi', model: 'Q5',
    year_from: 2009, year_to: 2023,
    tire_sizes: [
      { width: 235, height: 60, diameter: 18, type: 'stock' },
      { width: 255, height: 45, diameter: 20, type: 'stock' },
      { width: 275, height: 40, diameter: 20, type: 'optional' },
      { width: 285, height: 35, diameter: 21, type: 'optional' }
    ],
    search_aliases: ['Ауди Ку5', 'ауди ку5', 'Audi Q5'],
    search_tokens: 'Audi Q5 ауди ку5 кроссовер внедорожник'
  },
  
  # Volkswagen Tiguan - очень популярная модель
  {
    brand: 'Volkswagen', model: 'Tiguan',
    year_from: 2008, year_to: 2023,
    tire_sizes: [
      { width: 215, height: 65, diameter: 16, type: 'stock' },
      { width: 235, height: 55, diameter: 17, type: 'stock' },
      { width: 255, height: 45, diameter: 18, type: 'stock' },
      { width: 235, height: 50, diameter: 19, type: 'optional' },
      { width: 255, height: 40, diameter: 20, type: 'optional' }
    ],
    search_aliases: ['Фольксваген Тигуан', 'фольксваген тигуан', 'VW Tiguan', 'тигуан'],
    search_tokens: 'Volkswagen Tiguan фольксваген тигуан VW кроссовер 2019 2020 2021'
  },
  
  # Volkswagen Golf
  {
    brand: 'Volkswagen', model: 'Golf',
    year_from: 2009, year_to: 2023,
    tire_sizes: [
      { width: 205, height: 55, diameter: 16, type: 'stock' },
      { width: 225, height: 45, diameter: 17, type: 'stock' },
      { width: 225, height: 40, diameter: 18, type: 'optional' },
      { width: 235, height: 35, diameter: 19, type: 'optional' }
    ],
    search_aliases: ['Фольксваген Гольф', 'фольксваген гольф', 'VW Golf', 'гольф'],
    search_tokens: 'Volkswagen Golf фольксваген гольф VW хэтчбек'
  },
  
  # Toyota Camry
  {
    brand: 'Toyota', model: 'Camry',
    year_from: 2012, year_to: 2023,
    tire_sizes: [
      { width: 215, height: 60, diameter: 16, type: 'stock' },
      { width: 235, height: 45, diameter: 18, type: 'stock' },
      { width: 235, height: 40, diameter: 19, type: 'optional' }
    ],
    search_aliases: ['Тойота Камри', 'тойота камри', 'Toyota Camry', 'камри'],
    search_tokens: 'Toyota Camry тойота камри седан'
  },
  
  # Toyota RAV4
  {
    brand: 'Toyota', model: 'RAV4',
    year_from: 2013, year_to: 2023,
    tire_sizes: [
      { width: 225, height: 65, diameter: 17, type: 'stock' },
      { width: 235, height: 55, diameter: 19, type: 'stock' },
      { width: 235, height: 50, diameter: 19, type: 'optional' }
    ],
    search_aliases: ['Тойота РАВ4', 'тойота рав4', 'Toyota RAV4', 'рав4'],
    search_tokens: 'Toyota RAV4 тойота рав4 кроссовер внедорожник'
  },
  
  # Honda Civic
  {
    brand: 'Honda', model: 'Civic',
    year_from: 2012, year_to: 2023,
    tire_sizes: [
      { width: 215, height: 55, diameter: 16, type: 'stock' },
      { width: 235, height: 40, diameter: 18, type: 'stock' },
      { width: 245, height: 35, diameter: 19, type: 'optional' }
    ],
    search_aliases: ['Хонда Сивик', 'хонда сивик', 'Honda Civic', 'сивик'],
    search_tokens: 'Honda Civic хонда сивик седан хэтчбек'
  },
  
  # Honda CR-V
  {
    brand: 'Honda', model: 'CR-V',
    year_from: 2012, year_to: 2023,
    tire_sizes: [
      { width: 235, height: 60, diameter: 18, type: 'stock' },
      { width: 245, height: 50, diameter: 19, type: 'stock' },
      { width: 245, height: 45, diameter: 20, type: 'optional' }
    ],
    search_aliases: ['Хонда СР-В', 'хонда ср-в', 'Honda CR-V', 'Honda CRV'],
    search_tokens: 'Honda CR-V хонда ср-в CRV кроссовер внедорожник'
  },
  
  # Hyundai Tucson
  {
    brand: 'Hyundai', model: 'Tucson',
    year_from: 2016, year_to: 2023,
    tire_sizes: [
      { width: 225, height: 60, diameter: 17, type: 'stock' },
      { width: 245, height: 45, diameter: 19, type: 'stock' },
      { width: 245, height: 40, diameter: 20, type: 'optional' }
    ],
    search_aliases: ['Хюндай Туксон', 'хюндай туксон', 'Hyundai Tucson', 'туксон'],
    search_tokens: 'Hyundai Tucson хюндай туксон кроссовер внедорожник'
  },
  
  # Kia Sportage
  {
    brand: 'Kia', model: 'Sportage',
    year_from: 2016, year_to: 2023,
    tire_sizes: [
      { width: 225, height: 60, diameter: 17, type: 'stock' },
      { width: 245, height: 45, diameter: 19, type: 'stock' },
      { width: 245, height: 40, diameter: 20, type: 'optional' }
    ],
    search_aliases: ['Киа Спортейдж', 'киа спортейдж', 'Kia Sportage', 'спортейдж'],
    search_tokens: 'Kia Sportage киа спортейдж кроссовер внедорожник'
  },
  
  # Ford Focus
  {
    brand: 'Ford', model: 'Focus',
    year_from: 2011, year_to: 2023,
    tire_sizes: [
      { width: 215, height: 55, diameter: 16, type: 'stock' },
      { width: 235, height: 45, diameter: 17, type: 'stock' },
      { width: 235, height: 40, diameter: 18, type: 'optional' }
    ],
    search_aliases: ['Форд Фокус', 'форд фокус', 'Ford Focus', 'фокус'],
    search_tokens: 'Ford Focus форд фокус хэтчбек седан универсал'
  },
  
  # Skoda Octavia
  {
    brand: 'Skoda', model: 'Octavia',
    year_from: 2013, year_to: 2023,
    tire_sizes: [
      { width: 205, height: 55, diameter: 16, type: 'stock' },
      { width: 225, height: 45, diameter: 17, type: 'stock' },
      { width: 225, height: 40, diameter: 18, type: 'optional' }
    ],
    search_aliases: ['Шкода Октавия', 'шкода октавия', 'Skoda Octavia', 'октавия'],
    search_tokens: 'Skoda Octavia шкода октавия седан универсал'
  },
  
  # Renault Duster
  {
    brand: 'Renault', model: 'Duster',
    year_from: 2010, year_to: 2023,
    tire_sizes: [
      { width: 215, height: 65, diameter: 16, type: 'stock' },
      { width: 225, height: 60, diameter: 17, type: 'stock' },
      { width: 235, height: 55, diameter: 18, type: 'optional' }
    ],
    search_aliases: ['Рено Дастер', 'рено дастер', 'Renault Duster', 'дастер'],
    search_tokens: 'Renault Duster рено дастер кроссовер внедорожник'
  },
  
  # Mazda CX-5
  {
    brand: 'Mazda', model: 'CX-5',
    year_from: 2012, year_to: 2023,
    tire_sizes: [
      { width: 225, height: 65, diameter: 17, type: 'stock' },
      { width: 225, height: 55, diameter: 19, type: 'stock' },
      { width: 235, height: 50, diameter: 19, type: 'optional' }
    ],
    search_aliases: ['Мазда СХ-5', 'мазда сх-5', 'Mazda CX-5', 'CX5'],
    search_tokens: 'Mazda CX-5 мазда сх-5 CX5 кроссовер внедорожник'
  }
]

configurations_created = 0
configurations_updated = 0
configurations_skipped = 0

# Создаем или обновляем версию данных
version_record = TireDataVersion.find_or_create_by(version: current_version) do |v|
  v.source_description = "Полные конфигурации шин - производственные данные"
  v.imported_at = Time.current
  v.is_active = true
  v.file_checksums = { 
    "tire_configurations_full.rb" => Digest::MD5.hexdigest(File.read(__FILE__))
  }
  v.statistics = {}
end

# Деактивируем предыдущие версии
TireDataVersion.where.not(id: version_record.id).update_all(is_active: false)

puts "📊 Создание конфигураций шин версии #{current_version}..."

configurations_data.each_with_index do |config_data, index|
  brand = brands[config_data[:brand]]
  
  unless brand
    puts "  ⚠️ Бренд #{config_data[:brand]} не найден для конфигурации #{index + 1}"
    configurations_skipped += 1
    next
  end
  
  model = models["#{config_data[:brand]}|#{config_data[:model]}"]
  
  unless model
    puts "  ⚠️ Модель #{config_data[:brand]} #{config_data[:model]} не найдена для конфигурации #{index + 1}"
    configurations_skipped += 1
    next
  end
  
  # Ищем существующую конфигурацию
  existing_config = CarTireConfiguration.find_by(
    brand_id: brand.id,
    model_id: model.id,
    year_from: config_data[:year_from],
    year_to: config_data[:year_to]
  )
  
  if existing_config
    # Обновляем существующую конфигурацию
    existing_config.update!(
      tire_sizes: config_data[:tire_sizes],
      search_aliases: config_data[:search_aliases],
      search_tokens: config_data[:search_tokens],
      data_version: current_version,
      last_updated: Time.current,
      is_active: true,
      is_deprecated: false
    )
    configurations_updated += 1
    puts "  ♻️ Обновлена конфигурация: #{config_data[:brand]} #{config_data[:model]} (#{config_data[:year_from]}-#{config_data[:year_to]})"
  else
    # Создаем новую конфигурацию
    CarTireConfiguration.create!(
      brand_id: brand.id,
      model_id: model.id,
      year_from: config_data[:year_from],
      year_to: config_data[:year_to],
      tire_sizes: config_data[:tire_sizes],
      search_aliases: config_data[:search_aliases],
      search_tokens: config_data[:search_tokens],
      data_version: current_version,
      last_updated: Time.current,
      is_active: true,
      is_deprecated: false
    )
    configurations_created += 1
    puts "  ✅ Создана конфигурация: #{config_data[:brand]} #{config_data[:model]} (#{config_data[:year_from]}-#{config_data[:year_to]})"
  end
  
  # Показываем прогресс каждые 5 записей
  if (index + 1) % 5 == 0
    puts "    📈 Обработано #{index + 1} из #{configurations_data.length} конфигураций..."
  end
end

# Обновляем статистику версии
total_configurations = CarTireConfiguration.where(data_version: current_version).count
total_brands = CarTireConfiguration.where(data_version: current_version).distinct.count(:brand_id)
total_models = CarTireConfiguration.where(data_version: current_version).distinct.count(:model_id)

version_record.update!(
  statistics: {
    configurations_count: total_configurations,
    brands_count: total_brands,
    models_count: total_models,
    created_count: configurations_created,
    updated_count: configurations_updated,
    skipped_count: configurations_skipped,
    tire_sizes_count: CarTireConfiguration.where(data_version: current_version)
                                         .sum { |c| c.tire_sizes&.length || 0 }
  }
)

puts "\n📊 Статистика создания конфигураций шин:"
puts "  🆕 Создано новых конфигураций: #{configurations_created}"
puts "  🔄 Обновлено существующих: #{configurations_updated}"
puts "  ⏭️ Пропущено (нет бренда/модели): #{configurations_skipped}"
puts "  📋 Всего конфигураций в версии #{current_version}: #{total_configurations}"
puts "  🏷️ Уникальных брендов: #{total_brands}"
puts "  🚗 Уникальных моделей: #{total_models}"

# Статистика по размерам шин
puts "\n🔍 Статистика размеров шин:"
diameter_stats = CarTireConfiguration.where(data_version: current_version, is_active: true)
                                     .map { |c| c.tire_sizes&.map { |ts| ts['diameter'] } }
                                     .flatten
                                     .compact
                                     .tally
                                     .sort

diameter_stats.each do |diameter, count|
  puts "  ⚪ R#{diameter}: #{count} конфигураций"
end

# Статистика по типам шин
type_stats = CarTireConfiguration.where(data_version: current_version, is_active: true)
                                 .map { |c| c.tire_sizes&.map { |ts| ts['type'] } }
                                 .flatten
                                 .compact
                                 .tally

puts "\n📋 Статистика типов шин:"
type_stats.each do |type, count|
  puts "  🔖 #{type == 'stock' ? 'Заводские' : 'Опциональные'}: #{count} размеров"
end

puts "\n✅ Полные конфигурации шин успешно загружены!"
puts "   🎯 Система поиска шин готова к работе с #{total_configurations} конфигурациями"
puts "   📅 Версия данных: #{current_version}"
puts "   🚀 Статус: Активна и готова к использованию"