# db/seeds/02_regions_and_cities.rb
# Создание регионов и городов с переводами на русский и украинский языки

puts '=== Создание регионов и городов с переводами ==='

# Данные регионов с переводами
regions_data = [
  { 
    name_uk: 'Київська область',
    name_ru: 'Киевская область',
    cities: [
      { name_uk: 'Київ', name_ru: 'Киев' },
      { name_uk: 'Бровари', name_ru: 'Бровары' },
      { name_uk: 'Бориспіль', name_ru: 'Борисполь' },
      { name_uk: 'Ірпінь', name_ru: 'Ирпень' },
      { name_uk: 'Буча', name_ru: 'Буча' },
      { name_uk: 'Біла Церква', name_ru: 'Белая Церковь' },
      { name_uk: 'Фастів', name_ru: 'Фастов' }
    ]
  },
  { 
    name_uk: 'Львівська область',
    name_ru: 'Львовская область',
    cities: [
      { name_uk: 'Львів', name_ru: 'Львов' },
      { name_uk: 'Дрогобич', name_ru: 'Дрогобыч' },
      { name_uk: 'Стрий', name_ru: 'Стрый' },
      { name_uk: 'Трускавець', name_ru: 'Трускавец' },
      { name_uk: 'Червоноград', name_ru: 'Червоноград' },
      { name_uk: 'Самбір', name_ru: 'Самбор' },
      { name_uk: 'Борислав', name_ru: 'Борислав' }
    ]
  },
  { 
    name_uk: 'Одеська область',
    name_ru: 'Одесская область',
    cities: [
      { name_uk: 'Одеса', name_ru: 'Одесса' },
      { name_uk: 'Чорноморськ', name_ru: 'Черноморск' },
      { name_uk: 'Ізмаїл', name_ru: 'Измаил' },
      { name_uk: 'Білгород-Дністровський', name_ru: 'Белгород-Днестровский' },
      { name_uk: 'Южне', name_ru: 'Южное' },
      { name_uk: 'Подільськ', name_ru: 'Подольск' }
    ]
  },
  { 
    name_uk: 'Харківська область',
    name_ru: 'Харьковская область',
    cities: [
      { name_uk: 'Харків', name_ru: 'Харьков' },
      { name_uk: 'Ізюм', name_ru: 'Изюм' },
      { name_uk: 'Лозова', name_ru: 'Лозовая' },
      { name_uk: 'Чугуїв', name_ru: 'Чугуев' },
      { name_uk: 'Первомайський', name_ru: 'Первомайский' },
      { name_uk: 'Куп\'янськ', name_ru: 'Купянск' }
    ]
  },
  { 
    name_uk: 'Дніпропетровська область',
    name_ru: 'Днепропетровская область',
    cities: [
      { name_uk: 'Дніпро', name_ru: 'Днепр' },
      { name_uk: 'Кривий Ріг', name_ru: 'Кривой Рог' },
      { name_uk: 'Кам\'янське', name_ru: 'Каменское' },
      { name_uk: 'Нікополь', name_ru: 'Никополь' },
      { name_uk: 'Павлоград', name_ru: 'Павлоград' },
      { name_uk: 'Новомосковськ', name_ru: 'Новомосковск' }
    ]
  },
  { 
    name_uk: 'Запорізька область',
    name_ru: 'Запорожская область',
    cities: [
      { name_uk: 'Запоріжжя', name_ru: 'Запорожье' },
      { name_uk: 'Мелітополь', name_ru: 'Мелитополь' },
      { name_uk: 'Бердянськ', name_ru: 'Бердянск' },
      { name_uk: 'Енергодар', name_ru: 'Энергодар' },
      { name_uk: 'Токмак', name_ru: 'Токмак' },
      { name_uk: 'Василівка', name_ru: 'Васильевка' }
    ]
  },
  { 
    name_uk: 'Вінницька область',
    name_ru: 'Винницкая область',
    cities: [
      { name_uk: 'Вінниця', name_ru: 'Винница' },
      { name_uk: 'Жмеринка', name_ru: 'Жмеринка' },
      { name_uk: 'Могилів-Подільський', name_ru: 'Могилев-Подольский' },
      { name_uk: 'Хмільник', name_ru: 'Хмельник' },
      { name_uk: 'Козятин', name_ru: 'Козятин' },
      { name_uk: 'Калинівка', name_ru: 'Калиновка' }
    ]
  },
  { 
    name_uk: 'Івано-Франківська область',
    name_ru: 'Ивано-Франковская область',
    cities: [
      { name_uk: 'Івано-Франківськ', name_ru: 'Ивано-Франковск' },
      { name_uk: 'Коломия', name_ru: 'Коломыя' },
      { name_uk: 'Калуш', name_ru: 'Калуш' },
      { name_uk: 'Долина', name_ru: 'Долина' },
      { name_uk: 'Надвірна', name_ru: 'Надворная' },
      { name_uk: 'Болехів', name_ru: 'Болехов' }
    ]
  },
  { 
    name_uk: 'Тернопільська область',
    name_ru: 'Тернопольская область',
    cities: [
      { name_uk: 'Тернопіль', name_ru: 'Тернополь' },
      { name_uk: 'Чортків', name_ru: 'Чортков' },
      { name_uk: 'Кременець', name_ru: 'Кременец' },
      { name_uk: 'Збараж', name_ru: 'Збараж' },
      { name_uk: 'Бучач', name_ru: 'Бучач' },
      { name_uk: 'Борщів', name_ru: 'Борщев' }
    ]
  },
  { 
    name_uk: 'Житомирська область',
    name_ru: 'Житомирская область',
    cities: [
      { name_uk: 'Житомир', name_ru: 'Житомир' },
      { name_uk: 'Бердичів', name_ru: 'Бердичев' },
      { name_uk: 'Коростень', name_ru: 'Коростень' },
      { name_uk: 'Новоград-Волинський', name_ru: 'Новоград-Волынский' },
      { name_uk: 'Малин', name_ru: 'Малин' },
      { name_uk: 'Радомишль', name_ru: 'Радомышль' }
    ]
  }
]

# Счетчики
regions_created = 0
regions_updated = 0
cities_created = 0
cities_updated = 0

puts "📍 Обработка регионов и городов с переводами..."

# Обрабатываем каждый регион
regions_data.each do |region_data|
  # Находим или создаем регион по украинскому названию (основной ключ)
  region = Region.find_or_initialize_by(name: region_data[:name_uk])
  
  # Устанавливаем переводы
  region.name_ru = region_data[:name_ru]
  region.name_uk = region_data[:name_uk]
  
  if region.persisted?
    if region.changed?
      if region.save
        puts "  🔄 Обновлен регион: #{region.name} (ID: #{region.id}) - добавлены переводы"
        regions_updated += 1
      else
        puts "  ❌ Ошибка обновления региона #{region_data[:name_uk]}: #{region.errors.full_messages.join(', ')}"
        next
      end
    else
      puts "  ✅ Регион уже существует: #{region.name} (ID: #{region.id})"
      regions_updated += 1
    end
  else
    if region.save
      puts "  ✨ Создан регион: #{region.name} (ID: #{region.id}) с переводами"
      regions_created += 1
    else
      puts "  ❌ Ошибка создания региона #{region_data[:name_uk]}: #{region.errors.full_messages.join(', ')}"
      next
    end
  end
  
  # Обрабатываем города региона
  region_data[:cities].each do |city_data|
    city = City.find_or_initialize_by(name: city_data[:name_uk], region: region)
    
    # Устанавливаем переводы
    city.name_ru = city_data[:name_ru]
    city.name_uk = city_data[:name_uk]
    
    if city.persisted?
      if city.changed?
        if city.save
          puts "    🔄 Обновлен город: #{city.name} (ID: #{city.id}) - добавлены переводы"
          cities_updated += 1
        else
          puts "    ❌ Ошибка обновления города #{city_data[:name_uk]}: #{city.errors.full_messages.join(', ')}"
        end
      else
        puts "    ✅ Город уже существует: #{city.name}"
        cities_updated += 1
      end
    else
      if city.save
        puts "    ✨ Создан город: #{city.name} (ID: #{city.id}) с переводами"
        cities_created += 1
      else
        puts "    ❌ Ошибка создания города #{city_data[:name_uk]}: #{city.errors.full_messages.join(', ')}"
      end
    end
  end
end

puts "\n📊 Результат:"
puts "  Регионы - создано: #{regions_created}, обновлено: #{regions_updated}"
puts "  Города - создано: #{cities_created}, обновлено: #{cities_updated}"
puts "  Всего регионов: #{Region.count}"
puts "  Всего городов: #{City.count}"

# Выводим ID основных городов для справки с переводами
puts "\n📋 ID основных городов для справки (с переводами):"
major_cities_uk = ['Київ', 'Львів', 'Одеса', 'Харків', 'Дніпро', 'Запоріжжя', 'Вінниця', 'Івано-Франківськ']
major_cities_uk.each do |city_name_uk|
  city = City.find_by(name: city_name_uk)
  if city
    puts "  #{city.name_uk} / #{city.name_ru}: ID #{city.id} (регион: #{city.region.name_uk} / #{city.region.name_ru})"
  end
end

puts "\n✅ Регионы и города с переводами успешно созданы/обновлены!" 