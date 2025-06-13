# db/seeds/regions_and_cities.rb
# Создание базовых регионов и городов для приложения

puts 'Creating regions and cities...'

# Проверяем существующие записи
existing_regions = Region.count
existing_cities = City.count
puts "  Found #{existing_regions} existing regions and #{existing_cities} existing cities"

# Создаем регионы и города
regions_data = [
  { 
    name: 'Київська область', 
    cities: ['Київ', 'Бровари', 'Бориспіль', 'Ірпінь', 'Буча']
  },
  { 
    name: 'Львівська область', 
    cities: ['Львів', 'Дрогобич', 'Стрий', 'Трускавець', 'Червоноград']
  },
  { 
    name: 'Одеська область', 
    cities: ['Одеса', 'Чорноморськ', 'Ізмаїл', 'Білгород-Дністровський', 'Южне']
  },
  { 
    name: 'Харківська область', 
    cities: ['Харків', 'Ізюм', 'Лозова', 'Чугуїв', 'Первомайський']
  },
  { 
    name: 'Дніпропетровська область', 
    cities: ['Дніпро', 'Кривий Ріг', 'Кам\'янське', 'Нікополь', 'Павлоград']
  },
  { 
    name: 'Запорізька область', 
    cities: ['Запоріжжя', 'Мелітополь', 'Бердянськ', 'Енергодар', 'Токмак']
  },
  { 
    name: 'Вінницька область', 
    cities: ['Вінниця', 'Жмеринка', 'Могилів-Подільський', 'Хмільник', 'Козятин']
  },
  { 
    name: 'Івано-Франківська область', 
    cities: ['Івано-Франківськ', 'Коломия', 'Калуш', 'Долина', 'Надвірна']
  }
]

# Счетчики для созданных записей
regions_count = 0
cities_count = 0

# Создаем регионы и города
regions_data.each do |region_data|
  # Проверяем, существует ли регион
  region = Region.find_by(name: region_data[:name])
  
  # Если регион не существует, создаем его
  if region.nil?
    region = Region.create!(name: region_data[:name])
    regions_count += 1
  end
  
  # Создаем города для региона
  region_data[:cities].each do |city_name|
    # Проверяем, существует ли город
    city = City.find_by(name: city_name)
    
    # Если город не существует, создаем его
    if city.nil?
      city = City.create!(name: city_name, region: region)
      cities_count += 1
    elsif city.region_id != region.id
      # Если город существует, но с другим регионом, обновляем его
      city.update!(region: region)
      cities_count += 1
    end
  end
end

puts "  Created #{regions_count} new regions and #{cities_count} new cities"
puts "  Total regions: #{Region.count}, total cities: #{City.count}"
puts "  Regions: #{Region.limit(10).pluck(:name).join(', ')}"
puts "  Cities sample: #{City.limit(10).pluck(:name).join(', ')}" 