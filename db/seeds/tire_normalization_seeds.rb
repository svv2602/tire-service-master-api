# frozen_string_literal: true

# Заполнение справочных таблиц базовыми данными для системы нормализации

puts "🌱 Загрузка справочников для нормализации шин..."

# ===== СТРАНЫ ПРОИЗВОДСТВА =====
countries_data = [
  {
    name: 'Германия',
    iso_code: 'DE',
    rating_score: 10,
    aliases: ['germany', 'deutschland', 'немецкая', 'германская']
  },
  {
    name: 'Япония',
    iso_code: 'JP', 
    rating_score: 10,
    aliases: ['japan', 'японская', 'япония']
  },
  {
    name: 'Южная Корея',
    iso_code: 'KR',
    rating_score: 9,
    aliases: ['south korea', 'корея', 'korean', 'корейская']
  },
  {
    name: 'Франция',
    iso_code: 'FR',
    rating_score: 9,
    aliases: ['france', 'французская', 'франция']
  },
  {
    name: 'Италия',
    iso_code: 'IT',
    rating_score: 8,
    aliases: ['italy', 'итальянская', 'италия']
  },
  {
    name: 'Финляндия',
    iso_code: 'FI',
    rating_score: 9,
    aliases: ['finland', 'финская', 'финляндия']
  },
  {
    name: 'США',
    iso_code: 'US',
    rating_score: 8,
    aliases: ['usa', 'united states', 'америка', 'американская']
  },
  {
    name: 'Турция',
    iso_code: 'TR',
    rating_score: 7,
    aliases: ['turkey', 'турецкая', 'турция']
  },
  {
    name: 'Китай',
    iso_code: 'CN',
    rating_score: 5,
    aliases: ['china', 'китайская', 'китай']
  },
  {
    name: 'Россия',
    iso_code: 'RU',
    rating_score: 6,
    aliases: ['russia', 'российская', 'россия', 'рф']
  },
  {
    name: 'Беларусь',
    iso_code: 'BY',
    rating_score: 6,
    aliases: ['belarus', 'белорусская', 'беларусь']
  },
  {
    name: 'Украина',
    iso_code: 'UA',
    rating_score: 6,
    aliases: ['ukraine', 'украинская', 'украина']
  }
]

countries_data.each do |country_attrs|
  country = Country.find_or_initialize_by(iso_code: country_attrs[:iso_code])
  country.assign_attributes(country_attrs)
  country.save!
  puts "  ✅ Страна: #{country.name} (#{country.iso_code}) - рейтинг #{country.rating_score}"
end

# ===== ПРЕМИУМ БРЕНДЫ ШИН =====
premium_brands_data = [
  {
    name: 'Michelin',
    rating_score: 10,
    is_premium: true,
    country: Country.find_by(iso_code: 'FR'),
    aliases: ['мишлен', 'мишелин', 'мишлин']
  },
  {
    name: 'Continental',
    rating_score: 10,
    is_premium: true,
    country: Country.find_by(iso_code: 'DE'),
    aliases: ['континенталь', 'континентал', 'conti']
  },
  {
    name: 'Pirelli',
    rating_score: 9,
    is_premium: true,
    country: Country.find_by(iso_code: 'IT'),
    aliases: ['пирелли', 'пирели', 'пирелли']
  },
  {
    name: 'Bridgestone',
    rating_score: 9,
    is_premium: true,
    country: Country.find_by(iso_code: 'JP'),
    aliases: ['бриджстоун', 'бриджстон', 'бридж']
  },
  {
    name: 'Nokian',
    rating_score: 9,
    is_premium: true,
    country: Country.find_by(iso_code: 'FI'),
    aliases: ['нокиан', 'нокиа', 'nokian tyres']
  },
  {
    name: 'Goodyear',
    rating_score: 8,
    is_premium: true,
    country: Country.find_by(iso_code: 'US'),
    aliases: ['гудиер', 'гудиар', 'good year']
  }
]

# ===== ПОПУЛЯРНЫЕ БРЕНДЫ =====
popular_brands_data = [
  {
    name: 'Hankook',
    rating_score: 7,
    is_premium: false,
    country: Country.find_by(iso_code: 'KR'),
    aliases: ['ханкук', 'хэнкук', 'hankook tire']
  },
  {
    name: 'Yokohama',
    rating_score: 7,
    is_premium: false,
    country: Country.find_by(iso_code: 'JP'),
    aliases: ['йокохама', 'иокохама', 'yokohama tire']
  },
  {
    name: 'Kumho',
    rating_score: 6,
    is_premium: false,
    country: Country.find_by(iso_code: 'KR'),
    aliases: ['кумхо', 'kumho tire']
  },
  {
    name: 'Dunlop',
    rating_score: 7,
    is_premium: false,
    country: Country.find_by(iso_code: 'US'),
    aliases: ['данлоп', 'dunlop tire']
  },
  {
    name: 'Falken',
    rating_score: 6,
    is_premium: false,
    country: Country.find_by(iso_code: 'JP'),
    aliases: ['фалькен', 'фалкен']
  },
  {
    name: 'Toyo',
    rating_score: 6,
    is_premium: false,
    country: Country.find_by(iso_code: 'JP'),
    aliases: ['тойо', 'toyo tire']
  }
]

# ===== БЮДЖЕТНЫЕ БРЕНДЫ =====
budget_brands_data = [
  {
    name: 'Triangle',
    rating_score: 4,
    is_premium: false,
    country: Country.find_by(iso_code: 'CN'),
    aliases: ['треугольник', 'триангл']
  },
  {
    name: 'Linglong',
    rating_score: 4,
    is_premium: false,
    country: Country.find_by(iso_code: 'CN'),
    aliases: ['линглонг', 'лингlong']
  },
  {
    name: 'Кама',
    rating_score: 5,
    is_premium: false,
    country: Country.find_by(iso_code: 'RU'),
    aliases: ['kama', 'кама тайр']
  },
  {
    name: 'Белшина',
    rating_score: 5,
    is_premium: false,
    country: Country.find_by(iso_code: 'BY'),
    aliases: ['belshina', 'белшина тайр']
  },
  {
    name: 'Росава',
    rating_score: 5,
    is_premium: false,
    country: Country.find_by(iso_code: 'UA'),
    aliases: ['rosava', 'росава тайр']
  }
]

# Создаем все бренды
all_brands_data = premium_brands_data + popular_brands_data + budget_brands_data

all_brands_data.each do |brand_attrs|
  brand = TireBrand.find_or_initialize_by(normalized_name: brand_attrs[:name].downcase)
  brand.assign_attributes(brand_attrs.except(:country))
  brand.country = brand_attrs[:country]
  brand.save!
  puts "  ✅ Бренд: #{brand.name} - рейтинг #{brand.rating_score} (#{'премиум' if brand.is_premium})"
end

# ===== ПОПУЛЯРНЫЕ МОДЕЛИ ШИН =====
tire_models_data = [
  # Michelin модели
  {
    brand_name: 'Michelin',
    models: [
      { name: 'Pilot Sport 4', rating_score: 10, season_type: 'summer', aliases: ['пилот спорт 4', 'ps4'] },
      { name: 'Energy Saver', rating_score: 8, season_type: 'summer', aliases: ['энерджи сейвер', 'энерги'] },
      { name: 'X-Ice North', rating_score: 9, season_type: 'winter', aliases: ['икс айс норт', 'x ice'] },
      { name: 'Latitude Tour', rating_score: 8, season_type: 'all_season', aliases: ['латитуд тур'] }
    ]
  },
  # Continental модели
  {
    brand_name: 'Continental',
    models: [
      { name: 'Premium Contact', rating_score: 9, season_type: 'summer', aliases: ['премиум контакт', 'pc6'] },
      { name: 'Eco Contact', rating_score: 8, season_type: 'summer', aliases: ['эко контакт', 'ec6'] },
      { name: 'Winter Contact', rating_score: 9, season_type: 'winter', aliases: ['винтер контакт', 'wc'] },
      { name: 'Cross Contact', rating_score: 8, season_type: 'all_season', aliases: ['кросс контакт'] }
    ]
  },
  # Pirelli модели
  {
    brand_name: 'Pirelli',
    models: [
      { name: 'P Zero', rating_score: 10, season_type: 'summer', aliases: ['п зеро', 'pzero'] },
      { name: 'Cinturato', rating_score: 8, season_type: 'summer', aliases: ['чинтурато', 'цинтурато'] },
      { name: 'Winter Sottozero', rating_score: 9, season_type: 'winter', aliases: ['винтер соттозеро'] },
      { name: 'Scorpion Verde', rating_score: 8, season_type: 'all_season', aliases: ['скорпион верде'] }
    ]
  }
]

tire_models_data.each do |brand_data|
  brand = TireBrand.find_by(name: brand_data[:brand_name])
  next unless brand
  
  brand_data[:models].each do |model_attrs|
    model = TireModel.find_or_initialize_by(
      tire_brand: brand,
      normalized_name: model_attrs[:name].downcase
    )
    model.assign_attributes(model_attrs.except(:aliases))
    model.aliases = model_attrs[:aliases] || []
    model.save!
    puts "  ✅ Модель: #{brand.name} #{model.name} - рейтинг #{model.rating_score}"
  end
end

puts "🎉 Справочники успешно загружены!"
puts "📊 Статистика:"
puts "  - Стран: #{Country.count}"
puts "  - Брендов: #{TireBrand.count}"
puts "  - Моделей: #{TireModel.count}"