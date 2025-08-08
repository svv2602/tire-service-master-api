# frozen_string_literal: true

# Сиды для справочника стран производства шин
# Создано на основе анализа данных из supplier_tire_products
puts "📍 Создание справочника стран производства шин..."

# Маппинг стран с алиасами и рейтингами качества производства
countries_data = [
  {
    name: "Германия",
    iso_code: "DE",
    rating_score: 10,
    aliases: ["Германия", "Germany", "DE"]
  },
  {
    name: "Япония", 
    iso_code: "JP",
    rating_score: 10,
    aliases: ["Япония", "Japan", "JP"]
  },
  {
    name: "Финляндия",
    iso_code: "FI", 
    rating_score: 10,
    aliases: ["Финляндия", "Finland", "FI"]
  },
  {
    name: "Франция",
    iso_code: "FR",
    rating_score: 9,
    aliases: ["Франция", "France", "FR"]
  },
  {
    name: "Италия",
    iso_code: "IT",
    rating_score: 9,
    aliases: ["Италия", "Italy", "IT"]
  },
  {
    name: "США",
    iso_code: "US",
    rating_score: 9,
    aliases: ["США", "United States", "America", "US", "USA"]
  },
  {
    name: "Канада",
    iso_code: "CA",
    rating_score: 9,
    aliases: ["Канада", "Canada", "CA"]
  },
  {
    name: "Венгрия",
    iso_code: "HU",
    rating_score: 8,
    aliases: ["Венгрия", "Hungary", "HU"]
  },
  {
    name: "Чехия",
    iso_code: "CZ",
    rating_score: 8,
    aliases: ["Чехия", "Czech Republic", "CZ"]
  },
  {
    name: "Словения",
    iso_code: "SI",
    rating_score: 8,
    aliases: ["Словения", "Slovenia", "SI"]
  },
  {
    name: "Польша",
    iso_code: "PL",
    rating_score: 7,
    aliases: ["Польша", "Poland", "PL"]
  },
  {
    name: "Румыния",
    iso_code: "RO",
    rating_score: 7,
    aliases: ["Румыния", "Romania", "RO"]
  },
  {
    name: "Португалия",
    iso_code: "PT",
    rating_score: 7,
    aliases: ["Португалия", "Portugal", "PT"]
  },
  {
    name: "Словакия",
    iso_code: "SK",
    rating_score: 7,
    aliases: ["Словакия", "Slovakia", "SK"]
  },
  {
    name: "Испания",
    iso_code: "ES",
    rating_score: 7,
    aliases: ["Испания", "Spain", "ES"]
  },
  {
    name: "Сербия",
    iso_code: "RS",
    rating_score: 6,
    aliases: ["Сербия", "Serbia", "RS"]
  },
  {
    name: "Украина",
    iso_code: "UA",
    rating_score: 6,
    aliases: ["Украина", "Ukraine", "UA"]
  },
  {
    name: "Турция",
    iso_code: "TR",
    rating_score: 6,
    aliases: ["Турция", "Turkey", "TR"]
  },
  {
    name: "Корея", 
    iso_code: "KR",
    rating_score: 7,
    aliases: ["Корея", "Korea", "South Korea", "KR"]
  },
  {
    name: "Тайвань",
    iso_code: "TW",
    rating_score: 6,
    aliases: ["Тайвань", "Taiwan", "TW"]
  },
  {
    name: "Китай",
    iso_code: "CN",
    rating_score: 5,
    aliases: ["Китай", "China", "CN"]
  },
  {
    name: "Таиланд",
    iso_code: "TH",
    rating_score: 5,
    aliases: ["Таиланд", "Thailand", "TH"]
  },
  {
    name: "Малайзия",
    iso_code: "MY",
    rating_score: 5,
    aliases: ["Малайзия", "Malaysia", "MY"]
  },
  {
    name: "Индонезия",
    iso_code: "ID",
    rating_score: 5,
    aliases: ["Индонезия", "Indonesia", "ID"]
  },
  {
    name: "Англия",
    iso_code: "GB",
    rating_score: 8,
    aliases: ["Англия", "England", "United Kingdom", "UK", "GB"]
  },
  {
    name: "Нидерланды",
    iso_code: "NL",
    rating_score: 8,
    aliases: ["Нидерланды", "Netherlands", "Holland", "NL"]
  },
  {
    name: "Европейский Союз",
    iso_code: "EU",
    rating_score: 8,
    aliases: ["ЕС", "EU", "European Union", "Европейский Союз"]
  },
  {
    name: "Неопределено",
    iso_code: nil,
    rating_score: 1,
    aliases: ["Уточняйте", "Unknown", "Неопределено", "N/A"]
  }
]

# Создание или обновление стран
created_count = 0
updated_count = 0

countries_data.each do |country_attrs|
  # Нормализуем название для поиска
  normalized_name = Country.send(:normalize_string, country_attrs[:name])
  
  # Ищем существующую страну по нормализованному имени
  country = Country.find_or_initialize_by(normalized_name: normalized_name)
  
  if country.new_record?
    country.assign_attributes(country_attrs)
    country.save!
    created_count += 1
    puts "  ✅ Создано: #{country.name} (рейтинг: #{country.rating_score})"
  else
    # Обновляем только если данные изменились
    changes_made = false
    
    country_attrs.each do |key, value|
      next if key == :name || key == :normalized_name # Не обновляем имя
      
      if country.public_send(key) != value
        country.public_send("#{key}=", value)
        changes_made = true
      end
    end
    
    if changes_made
      country.save!
      updated_count += 1
      puts "  🔄 Обновлено: #{country.name}"
    end
  end
end

puts "\n📊 СТАТИСТИКА СОЗДАНИЯ СТРАН:"
puts "  ✅ Создано новых стран: #{created_count}"
puts "  🔄 Обновлено существующих: #{updated_count}"
puts "  📍 Всего стран в базе: #{Country.count}"

# Проверка и вывод статистики по рейтингам
rating_stats = Country.group(:rating_score).count.sort_by { |rating, _| -rating }
puts "\n🏆 СТАТИСТИКА ПО РЕЙТИНГАМ КАЧЕСТВА:"
rating_stats.each do |rating, count|
  quality = case rating
           when 10 then "Премиум"
           when 9 then "Высокое"
           when 8 then "Хорошее"
           when 7 then "Среднее+"
           when 6 then "Среднее"
           when 5 then "Базовое"
           else "Низкое"
           end
  puts "  #{rating}/10 (#{quality}): #{count} стран"
end

puts "✅ Справочник стран успешно создан!"