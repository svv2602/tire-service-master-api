# db/seeds/02_regions_and_cities.rb
# Создание регионов и городов с динамическими ID

puts '=== Создание регионов и городов ==='

# Данные регионов и городов
regions_data = [
  { 
    name: 'Київська область', 
    cities: ['Київ', 'Бровари', 'Бориспіль', 'Ірпінь', 'Буча', 'Біла Церква', 'Фастів']
  },
  { 
    name: 'Львівська область', 
    cities: ['Львів', 'Дрогобич', 'Стрий', 'Трускавець', 'Червоноград', 'Самбір', 'Борислав']
  },
  { 
    name: 'Одеська область', 
    cities: ['Одеса', 'Чорноморськ', 'Ізмаїл', 'Білгород-Дністровський', 'Южне', 'Подільськ']
  },
  { 
    name: 'Харківська область', 
    cities: ['Харків', 'Ізюм', 'Лозова', 'Чугуїв', 'Первомайський', 'Куп\'янськ']
  },
  { 
    name: 'Дніпропетровська область', 
    cities: ['Дніпро', 'Кривий Ріг', 'Кам\'янське', 'Нікополь', 'Павлоград', 'Новомосковськ']
  },
  { 
    name: 'Запорізька область', 
    cities: ['Запоріжжя', 'Мелітополь', 'Бердянськ', 'Енергодар', 'Токмак', 'Василівка']
  },
  { 
    name: 'Вінницька область', 
    cities: ['Вінниця', 'Жмеринка', 'Могилів-Подільський', 'Хмільник', 'Козятин', 'Калинівка']
  },
  { 
    name: 'Івано-Франківська область', 
    cities: ['Івано-Франківськ', 'Коломия', 'Калуш', 'Долина', 'Надвірна', 'Болехів']
  },
  { 
    name: 'Тернопільська область', 
    cities: ['Тернопіль', 'Чортків', 'Кременець', 'Збараж', 'Бучач', 'Борщів']
  },
  { 
    name: 'Житомирська область', 
    cities: ['Житомир', 'Бердичів', 'Коростень', 'Новоград-Волинський', 'Малин', 'Радомишль']
  }
]

# Счетчики
regions_created = 0
regions_updated = 0
cities_created = 0
cities_updated = 0

puts "📍 Обработка регионов и городов..."

# Обрабатываем каждый регион
regions_data.each do |region_data|
  # Находим или создаем регион
  region = Region.find_or_initialize_by(name: region_data[:name])
  
  if region.persisted?
    puts "  ✅ Регион уже существует: #{region.name} (ID: #{region.id})"
    regions_updated += 1
  else
    if region.save
      puts "  ✨ Создан регион: #{region.name} (ID: #{region.id})"
      regions_created += 1
    else
      puts "  ❌ Ошибка создания региона #{region_data[:name]}: #{region.errors.full_messages.join(', ')}"
      next
    end
  end
  
  # Обрабатываем города региона
  region_data[:cities].each do |city_name|
    city = City.find_or_initialize_by(name: city_name, region: region)
    
    if city.persisted?
      puts "    ✅ Город уже существует: #{city.name}"
      cities_updated += 1
    else
      if city.save
        puts "    ✨ Создан город: #{city.name} (ID: #{city.id})"
        cities_created += 1
      else
        puts "    ❌ Ошибка создания города #{city_name}: #{city.errors.full_messages.join(', ')}"
      end
    end
  end
end

puts "\n📊 Результат:"
puts "  Регионы - создано: #{regions_created}, обновлено: #{regions_updated}"
puts "  Города - создано: #{cities_created}, обновлено: #{cities_updated}"
puts "  Всего регионов: #{Region.count}"
puts "  Всего городов: #{City.count}"

# Выводим ID основных городов для справки
puts "\n📋 ID основных городов для справки:"
major_cities = ['Київ', 'Львів', 'Одеса', 'Харків', 'Дніпро', 'Запоріжжя', 'Вінниця', 'Івано-Франківськ']
major_cities.each do |city_name|
  city = City.find_by(name: city_name)
  if city
    puts "  #{city.name}: ID #{city.id} (регион: #{city.region.name})"
  end
end

puts "✅ Регионы и города успешно созданы/обновлены!" 