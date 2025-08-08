# frozen_string_literal: true

# Сиды для справочника брендов шин
# Создано на основе анализа данных из supplier_tire_products
puts "🏷️ Создание справочника брендов шин..."

# Данные брендов с алиасами, странами и рейтингами
tire_brands_data = [
  # ПРЕМИУМ БРЕНДЫ (рейтинг 9-10)
  {
    name: "Michelin",
    country_name: "Франция", 
    rating_score: 10,
    is_premium: true,
    aliases: ["Michelin", "Мишлен", "MICHELIN"]
  },
  {
    name: "Continental",
    country_name: "Германия",
    rating_score: 10,
    is_premium: true,
    aliases: ["Continental", "Континенталь", "CONTINENTAL", "Conti"]
  },
  {
    name: "Pirelli",
    country_name: "Италия",
    rating_score: 9,
    is_premium: true,
    aliases: ["Pirelli", "Пирелли", "PIRELLI"]
  },
  {
    name: "Nokian Tyres",
    country_name: "Финляндия",
    rating_score: 10,
    is_premium: true,
    aliases: ["Nokian Tyres", "Nokian", "Нокиан", "NOKIAN"]
  },
  {
    name: "Goodyear",
    country_name: "США",
    rating_score: 9,
    is_premium: true,
    aliases: ["Goodyear", "Гудьир", "GOODYEAR", "Good Year"]
  },
  {
    name: "Bridgestone",
    country_name: "Япония",
    rating_score: 10,
    is_premium: true,
    aliases: ["Bridgestone", "Бриджстоун", "BRIDGESTONE"]
  },

  # ВЫСОКОЕ КАЧЕСТВО (рейтинг 7-8)
  {
    name: "Vredestein",
    country_name: "Нидерланды",
    rating_score: 8,
    is_premium: false,
    aliases: ["Vredestein", "Вредештайн", "VREDESTEIN"]
  },
  {
    name: "Kleber",
    country_name: "Франция",
    rating_score: 7,
    is_premium: false,
    aliases: ["Kleber", "Клебер", "KLEBER"]
  },
  {
    name: "Tigar",
    country_name: "Сербия",
    rating_score: 7,
    is_premium: false,
    aliases: ["Tigar", "Тигар", "TIGAR"]
  },
  {
    name: "Kormoran",
    country_name: "Польша",
    rating_score: 7,
    is_premium: false,
    aliases: ["Kormoran", "Кормаран", "KORMORAN"]
  },
  {
    name: "Uniroyal",
    country_name: "Германия",
    rating_score: 7,
    is_premium: false,
    aliases: ["Uniroyal", "Унироял", "UNIROYAL"]
  },
  {
    name: "Dunlop",
    country_name: "Англия",
    rating_score: 8,
    is_premium: false,
    aliases: ["Dunlop", "Данлоп", "DUNLOP"]
  },
  {
    name: "Firestone",
    country_name: "США",
    rating_score: 7,
    is_premium: false,
    aliases: ["Firestone", "Файрстоун", "FIRESTONE"]
  },
  {
    name: "Falken",
    country_name: "Япония",
    rating_score: 8,
    is_premium: false,
    aliases: ["Falken", "Фалькен", "FALKEN"]
  },
  {
    name: "Yokohama",
    country_name: "Япония",
    rating_score: 8,
    is_premium: false,
    aliases: ["Yokohama", "Йокохама", "YOKOHAMA"]
  },
  {
    name: "Toyo",
    country_name: "Япония",
    rating_score: 8,
    is_premium: false,
    aliases: ["Toyo", "Тойо", "TOYO"]
  },

  # СРЕДНЕЕ КАЧЕСТВО (рейтинг 5-6)
  {
    name: "Grenlander",
    country_name: "Китай",
    rating_score: 5,
    is_premium: false,
    aliases: ["Grenlander", "Гренландер", "GRENLANDER"]
  },
  {
    name: "Hankook",
    country_name: "Корея",
    rating_score: 7,
    is_premium: false,
    aliases: ["Hankook", "Ханкук", "HANKOOK"]
  },
  {
    name: "Kumho",
    country_name: "Корея",
    rating_score: 6,
    is_premium: false,
    aliases: ["Kumho", "Кумхо", "KUMHO"]
  },
  {
    name: "Nankang",
    country_name: "Тайвань",
    rating_score: 5,
    is_premium: false,
    aliases: ["Nankang", "Нанканг", "NANKANG"]
  },
  {
    name: "Nexen",
    country_name: "Корея",
    rating_score: 6,
    is_premium: false,
    aliases: ["Nexen", "Нексен", "NEXEN"]
  },
  {
    name: "Cooper",
    country_name: "США",
    rating_score: 7,
    is_premium: false,
    aliases: ["Cooper", "Купер", "COOPER"]
  },
  {
    name: "General Tire",
    country_name: "США",
    rating_score: 6,
    is_premium: false,
    aliases: ["General Tire", "General", "Дженерал", "GENERAL"]
  },
  {
    name: "Maxxis",
    country_name: "Тайвань",
    rating_score: 6,
    is_premium: false,
    aliases: ["Maxxis", "Макссис", "MAXXIS"]
  },
  {
    name: "BFGoodrich",
    country_name: "США",
    rating_score: 7,
    is_premium: false,
    aliases: ["BFGoodrich", "BF Goodrich", "БФ Гудрич", "BFGOODRICH"]
  },
  {
    name: "Matador",
    country_name: "Словакия",
    rating_score: 6,
    is_premium: false,
    aliases: ["Matador", "Матадор", "MATADOR"]
  },

  # БЮДЖЕТНЫЕ БРЕНДЫ (рейтинг 4-5)
  {
    name: "Triangle",
    country_name: "Китай",
    rating_score: 4,
    is_premium: false,
    aliases: ["Triangle", "Триангл", "TRIANGLE"]
  },
  {
    name: "Kenda",
    country_name: "Тайвань",
    rating_score: 4,
    is_premium: false,
    aliases: ["Kenda", "Кенда", "KENDA"]
  },
  {
    name: "Roadstone",
    country_name: "Корея",
    rating_score: 5,
    is_premium: false,
    aliases: ["Roadstone", "Роудстоун", "ROADSTONE"]
  },
  {
    name: "GT Radial",
    country_name: "Индонезия",
    rating_score: 4,
    is_premium: false,
    aliases: ["GT Radial", "GT", "ГТ Радиал", "GTRADIAL"]
  },
  {
    name: "Sailun",
    country_name: "Китай",
    rating_score: 4,
    is_premium: false,
    aliases: ["Sailun", "Сайлун", "SAILUN"]
  },
  {
    name: "Zeetex",
    country_name: "Дубай",
    rating_score: 4,
    is_premium: false,
    aliases: ["Zeetex", "Зитекс", "ZEETEX"]
  }
]

# Создание или обновление брендов
created_count = 0
updated_count = 0
country_not_found = []

tire_brands_data.each do |brand_attrs|
  # Ищем страну по названию
  country = nil
  if brand_attrs[:country_name]
    country = Country.active.find_by(
      normalized_name: Country.send(:normalize_string, brand_attrs[:country_name])
    )
    unless country
      country_not_found << brand_attrs[:country_name]
    end
  end

  # Нормализуем название бренда для поиска
  normalized_name = TireBrand.send(:normalize_string, brand_attrs[:name])
  
  # Ищем существующий бренд
  tire_brand = TireBrand.find_or_initialize_by(normalized_name: normalized_name)
  
  # Подготавливаем атрибуты для создания/обновления
  attrs = brand_attrs.except(:country_name)
  attrs[:country_id] = country&.id
  
  if tire_brand.new_record?
    tire_brand.assign_attributes(attrs)
    tire_brand.save!
    created_count += 1
    country_info = country ? "(#{country.name})" : "(страна не найдена)"
    puts "  ✅ Создано: #{tire_brand.name} #{country_info} - рейтинг #{tire_brand.rating_score}"
  else
    # Обновляем только если данные изменились
    changes_made = false
    
    attrs.each do |key, value|
      next if key == :name || key == :normalized_name
      
      if tire_brand.public_send(key) != value
        tire_brand.public_send("#{key}=", value)
        changes_made = true
      end
    end
    
    if changes_made
      tire_brand.save!
      updated_count += 1
      puts "  🔄 Обновлено: #{tire_brand.name}"
    end
  end
end

puts "\n📊 СТАТИСТИКА СОЗДАНИЯ БРЕНДОВ:"
puts "  ✅ Создано новых брендов: #{created_count}"
puts "  🔄 Обновлено существующих: #{updated_count}"
puts "  🏷️ Всего брендов в базе: #{TireBrand.count}"

# Предупреждения о не найденных странах
if country_not_found.any?
  puts "\n⚠️ ПРЕДУПРЕЖДЕНИЯ:"
  puts "  Не найдены страны: #{country_not_found.uniq.join(', ')}"
  puts "  Эти бренды созданы без привязки к стране"
end

# Статистика по рейтингам брендов
rating_stats = TireBrand.group(:rating_score).count.sort_by { |rating, _| -rating }
puts "\n🏆 СТАТИСТИКА ПО РЕЙТИНГАМ БРЕНДОВ:"
rating_stats.each do |rating, count|
  segment = case rating
           when 9..10 then "Премиум"
           when 7..8 then "Высокое качество"
           when 5..6 then "Среднее качество"
           when 3..4 then "Бюджетные"
           else "Низкокачественные"
           end
  puts "  #{rating}/10 (#{segment}): #{count} брендов"
end

# Статистика по премиум сегменту
premium_count = TireBrand.premium.count
regular_count = TireBrand.count - premium_count
puts "\n💎 СЕГМЕНТАЦИЯ:"
puts "  Премиум бренды: #{premium_count}"
puts "  Обычные бренды: #{regular_count}"

puts "✅ Справочник брендов шин успешно создан!"