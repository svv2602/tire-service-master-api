# Обработанные модели автомобилей для системы поиска шин
# Источник: обработанные данные из CSV файлов

puts "🚗 Создание обработанных моделей автомобилей..."

# Получаем существующие бренды для связывания
brands = CarBrand.all.index_by(&:name)

models_data = [
  # BMW модели
  { brand: 'BMW', name: '1 Series', search_aliases: ['1 серия', '1-я серия', 'первая серия', 'единичка'] },
  { brand: 'BMW', name: '2 Series', search_aliases: ['2 серия', '2-я серия', 'вторая серия', 'двойка'] },
  { brand: 'BMW', name: '3 Series', search_aliases: ['3 серия', '3-я серия', 'третья серия', 'тройка', '320i', '330i', '335i'] },
  { brand: 'BMW', name: '4 Series', search_aliases: ['4 серия', '4-я серия', 'четвертая серия', 'четверка'] },
  { brand: 'BMW', name: '5 Series', search_aliases: ['5 серия', '5-я серия', 'пятая серия', 'пятерка', '520i', '530i', '540i'] },
  { brand: 'BMW', name: '6 Series', search_aliases: ['6 серия', '6-я серия', 'шестая серия', 'шестерка'] },
  { brand: 'BMW', name: '7 Series', search_aliases: ['7 серия', '7-я серия', 'седьмая серия', 'семерка', '740i', '750i'] },
  { brand: 'BMW', name: '8 Series', search_aliases: ['8 серия', '8-я серия', 'восьмая серия', 'восьмерка'] },
  { brand: 'BMW', name: 'X1', search_aliases: ['БМВ Х1', 'икс1', 'x1'] },
  { brand: 'BMW', name: 'X2', search_aliases: ['БМВ Х2', 'икс2', 'x2'] },
  { brand: 'BMW', name: 'X3', search_aliases: ['БМВ Х3', 'икс3', 'x3'] },
  { brand: 'BMW', name: 'X4', search_aliases: ['БМВ Х4', 'икс4', 'x4'] },
  { brand: 'BMW', name: 'X5', search_aliases: ['БМВ Х5', 'икс5', 'x5'] },
  { brand: 'BMW', name: 'X6', search_aliases: ['БМВ Х6', 'икс6', 'x6'] },
  { brand: 'BMW', name: 'X7', search_aliases: ['БМВ Х7', 'икс7', 'x7'] },
  { brand: 'BMW', name: 'Z4', search_aliases: ['БМВ Z4', 'зет4', 'z4'] },
  
  # Mercedes-Benz модели
  { brand: 'Mercedes-Benz', name: 'A-Class', search_aliases: ['А-класс', 'а класс', 'A200', 'A250'] },
  { brand: 'Mercedes-Benz', name: 'B-Class', search_aliases: ['Б-класс', 'б класс', 'B200', 'B250'] },
  { brand: 'Mercedes-Benz', name: 'C-Class', search_aliases: ['С-класс', 'с класс', 'C200', 'C220', 'C300'] },
  { brand: 'Mercedes-Benz', name: 'E-Class', search_aliases: ['Е-класс', 'е класс', 'E200', 'E220', 'E300', 'E350'] },
  { brand: 'Mercedes-Benz', name: 'S-Class', search_aliases: ['С-класс', 'эс класс', 'S350', 'S400', 'S500'] },
  { brand: 'Mercedes-Benz', name: 'GLA', search_aliases: ['ГЛА', 'гла', 'GLA200', 'GLA250'] },
  { brand: 'Mercedes-Benz', name: 'GLB', search_aliases: ['ГЛБ', 'глб', 'GLB200', 'GLB250'] },
  { brand: 'Mercedes-Benz', name: 'GLC', search_aliases: ['ГЛС', 'глс', 'GLC200', 'GLC300'] },
  { brand: 'Mercedes-Benz', name: 'GLE', search_aliases: ['ГЛЕ', 'гле', 'GLE350', 'GLE450'] },
  { brand: 'Mercedes-Benz', name: 'GLS', search_aliases: ['ГЛС', 'глс', 'GLS350', 'GLS450'] },
  { brand: 'Mercedes-Benz', name: 'G-Class', search_aliases: ['Г-класс', 'г класс', 'Гелендваген', 'гелик', 'G350', 'G500'] },
  
  # Audi модели
  { brand: 'Audi', name: 'A1', search_aliases: ['А1', 'а1', 'Ауди А1'] },
  { brand: 'Audi', name: 'A3', search_aliases: ['А3', 'а3', 'Ауди А3'] },
  { brand: 'Audi', name: 'A4', search_aliases: ['А4', 'а4', 'Ауди А4'] },
  { brand: 'Audi', name: 'A5', search_aliases: ['А5', 'а5', 'Ауди А5'] },
  { brand: 'Audi', name: 'A6', search_aliases: ['А6', 'а6', 'Ауди А6'] },
  { brand: 'Audi', name: 'A7', search_aliases: ['А7', 'а7', 'Ауди А7'] },
  { brand: 'Audi', name: 'A8', search_aliases: ['А8', 'а8', 'Ауди А8'] },
  { brand: 'Audi', name: 'Q2', search_aliases: ['Ку2', 'ку2', 'Q2'] },
  { brand: 'Audi', name: 'Q3', search_aliases: ['Ку3', 'ку3', 'Q3'] },
  { brand: 'Audi', name: 'Q5', search_aliases: ['Ку5', 'ку5', 'Q5'] },
  { brand: 'Audi', name: 'Q7', search_aliases: ['Ку7', 'ку7', 'Q7'] },
  { brand: 'Audi', name: 'Q8', search_aliases: ['Ку8', 'ку8', 'Q8'] },
  { brand: 'Audi', name: 'TT', search_aliases: ['ТТ', 'тт', 'TT'] },
  
  # Volkswagen модели
  { brand: 'Volkswagen', name: 'Golf', search_aliases: ['Гольф', 'гольф', 'Golf GTI'] },
  { brand: 'Volkswagen', name: 'Passat', search_aliases: ['Пассат', 'пассат', 'Passat CC'] },
  { brand: 'Volkswagen', name: 'Polo', search_aliases: ['Поло', 'поло'] },
  { brand: 'Volkswagen', name: 'Jetta', search_aliases: ['Джетта', 'джетта'] },
  { brand: 'Volkswagen', name: 'Tiguan', search_aliases: ['Тигуан', 'тигуан', 'Tiguan Allspace'] },
  { brand: 'Volkswagen', name: 'Touareg', search_aliases: ['Туарег', 'туарег'] },
  { brand: 'Volkswagen', name: 'Arteon', search_aliases: ['Артеон', 'артеон'] },
  { brand: 'Volkswagen', name: 'T-Cross', search_aliases: ['Т-Кросс', 'т-кросс', 'T Cross'] },
  { brand: 'Volkswagen', name: 'T-Roc', search_aliases: ['Т-Рок', 'т-рок', 'T Roc'] },
  
  # Toyota модели
  { brand: 'Toyota', name: 'Corolla', search_aliases: ['Корола', 'корола', 'Королла', 'королла'] },
  { brand: 'Toyota', name: 'Camry', search_aliases: ['Камри', 'камри'] },
  { brand: 'Toyota', name: 'RAV4', search_aliases: ['РАВ4', 'рав4', 'RAV 4'] },
  { brand: 'Toyota', name: 'Highlander', search_aliases: ['Хайлендер', 'хайлендер'] },
  { brand: 'Toyota', name: 'Land Cruiser', search_aliases: ['Ленд Крузер', 'ленд крузер', 'Крузер', 'крузер'] },
  { brand: 'Toyota', name: 'Prius', search_aliases: ['Приус', 'приус'] },
  { brand: 'Toyota', name: 'Yaris', search_aliases: ['Ярис', 'ярис'] },
  { brand: 'Toyota', name: 'Avalon', search_aliases: ['Авалон', 'авалон'] },
  { brand: 'Toyota', name: 'C-HR', search_aliases: ['Си-ЭйчАр', 'си-эйчар', 'CHR'] },
  
  # Honda модели
  { brand: 'Honda', name: 'Civic', search_aliases: ['Сивик', 'сивик'] },
  { brand: 'Honda', name: 'Accord', search_aliases: ['Аккорд', 'аккорд'] },
  { brand: 'Honda', name: 'CR-V', search_aliases: ['СР-В', 'ср-в', 'CRV'] },
  { brand: 'Honda', name: 'HR-V', search_aliases: ['ЭйчАр-В', 'эйчар-в', 'HRV'] },
  { brand: 'Honda', name: 'Pilot', search_aliases: ['Пилот', 'пилот'] },
  { brand: 'Honda', name: 'Fit', search_aliases: ['Фит', 'фит'] },
  
  # Nissan модели
  { brand: 'Nissan', name: 'Altima', search_aliases: ['Альтима', 'альтима'] },
  { brand: 'Nissan', name: 'Sentra', search_aliases: ['Сентра', 'сентра'] },
  { brand: 'Nissan', name: 'Rogue', search_aliases: ['Роуг', 'роуг'] },
  { brand: 'Nissan', name: 'Murano', search_aliases: ['Мурано', 'мурано'] },
  { brand: 'Nissan', name: 'Pathfinder', search_aliases: ['Патфайндер', 'патфайндер'] },
  { brand: 'Nissan', name: 'X-Trail', search_aliases: ['Икс-Трейл', 'икс-трейл', 'X Trail'] },
  { brand: 'Nissan', name: 'Qashqai', search_aliases: ['Кашкай', 'кашкай'] },
  
  # Hyundai модели
  { brand: 'Hyundai', name: 'Elantra', search_aliases: ['Элантра', 'элантра'] },
  { brand: 'Hyundai', name: 'Sonata', search_aliases: ['Соната', 'соната'] },
  { brand: 'Hyundai', name: 'Tucson', search_aliases: ['Туксон', 'туксон'] },
  { brand: 'Hyundai', name: 'Santa Fe', search_aliases: ['Санта Фе', 'санта фе'] },
  { brand: 'Hyundai', name: 'Creta', search_aliases: ['Крета', 'крета'] },
  { brand: 'Hyundai', name: 'i30', search_aliases: ['и30', 'i 30'] },
  { brand: 'Hyundai', name: 'Kona', search_aliases: ['Кона', 'кона'] },
  
  # Kia модели
  { brand: 'Kia', name: 'Rio', search_aliases: ['Рио', 'рио'] },
  { brand: 'Kia', name: 'Cerato', search_aliases: ['Серато', 'серато'] },
  { brand: 'Kia', name: 'Optima', search_aliases: ['Оптима', 'оптима'] },
  { brand: 'Kia', name: 'Sportage', search_aliases: ['Спортейдж', 'спортейдж'] },
  { brand: 'Kia', name: 'Sorento', search_aliases: ['Соренто', 'соренто'] },
  { brand: 'Kia', name: 'Picanto', search_aliases: ['Пиканто', 'пиканто'] },
  { brand: 'Kia', name: 'Stinger', search_aliases: ['Стингер', 'стингер'] },
  
  # Ford модели
  { brand: 'Ford', name: 'Focus', search_aliases: ['Фокус', 'фокус'] },
  { brand: 'Ford', name: 'Fiesta', search_aliases: ['Фиеста', 'фиеста'] },
  { brand: 'Ford', name: 'Mondeo', search_aliases: ['Мондео', 'мондео'] },
  { brand: 'Ford', name: 'Explorer', search_aliases: ['Эксплорер', 'эксплорер'] },
  { brand: 'Ford', name: 'Escape', search_aliases: ['Эскейп', 'эскейп'] },
  { brand: 'Ford', name: 'Mustang', search_aliases: ['Мустанг', 'мустанг'] },
  { brand: 'Ford', name: 'F-150', search_aliases: ['Ф-150', 'ф-150', 'F150'] },
  
  # Chevrolet модели
  { brand: 'Chevrolet', name: 'Cruze', search_aliases: ['Круз', 'круз'] },
  { brand: 'Chevrolet', name: 'Malibu', search_aliases: ['Малибу', 'малибу'] },
  { brand: 'Chevrolet', name: 'Equinox', search_aliases: ['Эквинокс', 'эквинокс'] },
  { brand: 'Chevrolet', name: 'Tahoe', search_aliases: ['Тахо', 'тахо'] },
  { brand: 'Chevrolet', name: 'Suburban', search_aliases: ['Субурбан', 'субурбан'] },
  { brand: 'Chevrolet', name: 'Camaro', search_aliases: ['Камаро', 'камаро'] },
  { brand: 'Chevrolet', name: 'Corvette', search_aliases: ['Корветт', 'корветт'] },
  
  # Skoda модели
  { brand: 'Skoda', name: 'Octavia', search_aliases: ['Октавия', 'октавия'] },
  { brand: 'Skoda', name: 'Superb', search_aliases: ['Суперб', 'суперб'] },
  { brand: 'Skoda', name: 'Rapid', search_aliases: ['Рапид', 'рапид'] },
  { brand: 'Skoda', name: 'Kodiaq', search_aliases: ['Кодиак', 'кодиак'] },
  { brand: 'Skoda', name: 'Karoq', search_aliases: ['Карок', 'карок'] },
  { brand: 'Skoda', name: 'Scala', search_aliases: ['Скала', 'скала'] },
  
  # Renault модели
  { brand: 'Renault', name: 'Logan', search_aliases: ['Логан', 'логан'] },
  { brand: 'Renault', name: 'Sandero', search_aliases: ['Сандеро', 'сандеро'] },
  { brand: 'Renault', name: 'Duster', search_aliases: ['Дастер', 'дастер'] },
  { brand: 'Renault', name: 'Kaptur', search_aliases: ['Каптур', 'каптур'] },
  { brand: 'Renault', name: 'Megane', search_aliases: ['Меган', 'меган'] },
  { brand: 'Renault', name: 'Clio', search_aliases: ['Клио', 'клио'] },
  
  # Mazda модели
  { brand: 'Mazda', name: 'Mazda3', search_aliases: ['Мазда3', 'мазда3', 'Mazda 3'] },
  { brand: 'Mazda', name: 'Mazda6', search_aliases: ['Мазда6', 'мазда6', 'Mazda 6'] },
  { brand: 'Mazda', name: 'CX-3', search_aliases: ['СХ-3', 'сх-3', 'CX3'] },
  { brand: 'Mazda', name: 'CX-5', search_aliases: ['СХ-5', 'сх-5', 'CX5'] },
  { brand: 'Mazda', name: 'CX-9', search_aliases: ['СХ-9', 'сх-9', 'CX9'] },
  { brand: 'Mazda', name: 'MX-5', search_aliases: ['МХ-5', 'мх-5', 'MX5', 'Miata'] }
]

models_created = 0
models_updated = 0
models_skipped = 0

models_data.each do |model_data|
  brand = brands[model_data[:brand]]
  
  unless brand
    puts "  ⚠️ Бренд #{model_data[:brand]} не найден для модели #{model_data[:name]}"
    models_skipped += 1
    next
  end
  
  model = CarModel.find_or_initialize_by(
    name: model_data[:name],
    car_brand_id: brand.id
  )
  
  if model.new_record?
    model.save!
    models_created += 1
    puts "  ✅ Создана модель: #{model_data[:brand]} #{model_data[:name]}"
  else
    models_updated += 1
    puts "  ♻️ Обновлена модель: #{model_data[:brand]} #{model_data[:name]}"
  end
  
  # Сохраняем алиасы поиска для будущего использования в системе поиска шин
  model.update_column(:search_aliases, model_data[:search_aliases]) if model.respond_to?(:search_aliases)
end

puts "\n📊 Статистика создания моделей:"
puts "  🆕 Создано новых моделей: #{models_created}"
puts "  🔄 Обновлено существующих: #{models_updated}"
puts "  ⏭️ Пропущено (нет бренда): #{models_skipped}"
puts "  📋 Всего моделей в системе: #{CarModel.count}"

# Статистика по брендам
puts "\n📈 Модели по брендам:"
CarBrand.joins(:car_models).group('car_brands.name').count.sort_by { |_, count| -count }.first(10).each do |brand_name, count|
  puts "  🏷️ #{brand_name}: #{count} моделей"
end

puts "✅ Обработанные модели автомобилей успешно загружены!"
puts "   Система поиска шин готова к работе с #{CarModel.count} моделями автомобилей"