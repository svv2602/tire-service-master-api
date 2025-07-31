# Обработанные бренды автомобилей для системы поиска шин
# Источник: обработанные данные из CSV файлов

puts "🏷️ Создание обработанных брендов автомобилей..."

brands_data = [
  # Премиум немецкие бренды
  { name: 'BMW', search_aliases: ['БМВ', 'бмв', 'bmw', 'BMW', 'БиЭмВе'] },
  { name: 'Mercedes-Benz', search_aliases: ['Mercedes', 'Мерседес', 'мерседес', 'Benz', 'бенц'] },
  { name: 'Audi', search_aliases: ['Ауди', 'ауди', 'audi', 'AUDI'] },
  { name: 'Volkswagen', search_aliases: ['VW', 'Фольксваген', 'фольксваген', 'вольксваген', 'Volkswagen'] },
  { name: 'Porsche', search_aliases: ['Порше', 'порше', 'porsche', 'PORSCHE'] },
  
  # Японские бренды
  { name: 'Toyota', search_aliases: ['Тойота', 'тойота', 'toyota', 'TOYOTA'] },
  { name: 'Honda', search_aliases: ['Хонда', 'хонда', 'honda', 'HONDA'] },
  { name: 'Nissan', search_aliases: ['Ниссан', 'ниссан', 'nissan', 'NISSAN'] },
  { name: 'Mazda', search_aliases: ['Мазда', 'мазда', 'mazda', 'MAZDA'] },
  { name: 'Subaru', search_aliases: ['Субару', 'субару', 'subaru', 'SUBARU'] },
  { name: 'Mitsubishi', search_aliases: ['Митсубиси', 'митсубиси', 'mitsubishi', 'MITSUBISHI'] },
  { name: 'Lexus', search_aliases: ['Лексус', 'лексус', 'lexus', 'LEXUS'] },
  { name: 'Infiniti', search_aliases: ['Инфинити', 'инфинити', 'infiniti', 'INFINITI'] },
  { name: 'Acura', search_aliases: ['Акура', 'акура', 'acura', 'ACURA'] },
  
  # Корейские бренды
  { name: 'Hyundai', search_aliases: ['Хюндай', 'хюндай', 'хундай', 'hyundai', 'HYUNDAI'] },
  { name: 'Kia', search_aliases: ['Киа', 'киа', 'kia', 'KIA'] },
  { name: 'Genesis', search_aliases: ['Генезис', 'генезис', 'genesis', 'GENESIS'] },
  
  # Американские бренды
  { name: 'Ford', search_aliases: ['Форд', 'форд', 'ford', 'FORD'] },
  { name: 'Chevrolet', search_aliases: ['Шевроле', 'шевроле', 'chevrolet', 'CHEVROLET', 'Chevy'] },
  { name: 'Cadillac', search_aliases: ['Кадиллак', 'кадиллак', 'cadillac', 'CADILLAC'] },
  { name: 'Lincoln', search_aliases: ['Линкольн', 'линкольн', 'lincoln', 'LINCOLN'] },
  { name: 'Jeep', search_aliases: ['Джип', 'джип', 'jeep', 'JEEP'] },
  { name: 'Chrysler', search_aliases: ['Крайслер', 'крайслер', 'chrysler', 'CHRYSLER'] },
  { name: 'Dodge', search_aliases: ['Додж', 'додж', 'dodge', 'DODGE'] },
  
  # Французские бренды
  { name: 'Renault', search_aliases: ['Рено', 'рено', 'renault', 'RENAULT'] },
  { name: 'Peugeot', search_aliases: ['Пежо', 'пежо', 'peugeot', 'PEUGEOT'] },
  { name: 'Citroen', search_aliases: ['Ситроен', 'ситроен', 'citroen', 'CITROEN'] },
  
  # Итальянские бренды
  { name: 'Fiat', search_aliases: ['Фиат', 'фиат', 'fiat', 'FIAT'] },
  { name: 'Alfa Romeo', search_aliases: ['Альфа Ромео', 'альфа ромео', 'alfa romeo', 'ALFA ROMEO'] },
  { name: 'Ferrari', search_aliases: ['Феррари', 'феррари', 'ferrari', 'FERRARI'] },
  { name: 'Lamborghini', search_aliases: ['Ламборгини', 'ламборгини', 'lamborghini', 'LAMBORGHINI'] },
  { name: 'Maserati', search_aliases: ['Мазерати', 'мазерати', 'maserati', 'MASERATI'] },
  
  # Британские бренды
  { name: 'Land Rover', search_aliases: ['Ленд Ровер', 'ленд ровер', 'land rover', 'LAND ROVER'] },
  { name: 'Jaguar', search_aliases: ['Ягуар', 'ягуар', 'jaguar', 'JAGUAR'] },
  { name: 'Mini', search_aliases: ['Мини', 'мини', 'mini', 'MINI'] },
  { name: 'Bentley', search_aliases: ['Бентли', 'бентли', 'bentley', 'BENTLEY'] },
  { name: 'Rolls-Royce', search_aliases: ['Роллс-Ройс', 'роллс-ройс', 'rolls-royce', 'ROLLS-ROYCE'] },
  
  # Шведские бренды
  { name: 'Volvo', search_aliases: ['Вольво', 'вольво', 'volvo', 'VOLVO'] },
  { name: 'Saab', search_aliases: ['Сааб', 'сааб', 'saab', 'SAAB'] },
  
  # Чешские бренды
  { name: 'Skoda', search_aliases: ['Шкода', 'шкода', 'skoda', 'SKODA'] },
  
  # Испанские бренды
  { name: 'SEAT', search_aliases: ['Сеат', 'сеат', 'seat', 'SEAT'] },
  
  # Румынские бренды
  { name: 'Dacia', search_aliases: ['Дачия', 'дачия', 'dacia', 'DACIA'] },
  
  # Китайские бренды
  { name: 'Geely', search_aliases: ['Джили', 'джили', 'geely', 'GEELY'] },
  { name: 'BYD', search_aliases: ['БИД', 'бид', 'byd', 'BYD'] },
  { name: 'Great Wall', search_aliases: ['Грейт Волл', 'грейт волл', 'great wall', 'GREAT WALL'] },
  { name: 'Chery', search_aliases: ['Чери', 'чери', 'chery', 'CHERY'] },
  { name: 'JAC', search_aliases: ['ЖАК', 'жак', 'jac', 'JAC'] },
  
  # Украинские бренды
  { name: 'ZAZ', search_aliases: ['ЗАЗ', 'заз', 'zaz', 'ZAZ', 'Запорожец'] },
  
  # Российские бренды
  { name: 'Lada', search_aliases: ['Лада', 'лада', 'lada', 'LADA', 'ВАЗ', 'ваз'] },
  { name: 'UAZ', search_aliases: ['УАЗ', 'уаз', 'uaz', 'UAZ'] },
  { name: 'GAZ', search_aliases: ['ГАЗ', 'газ', 'gaz', 'GAZ'] }
]

brands_created = 0
brands_updated = 0

brands_data.each do |brand_data|
  brand = CarBrand.find_or_initialize_by(name: brand_data[:name])
  
  if brand.new_record?
    brand.save!
    brands_created += 1
    puts "  ✅ Создан бренд: #{brand_data[:name]}"
  else
    brands_updated += 1
    puts "  ♻️ Обновлен бренд: #{brand_data[:name]}"
  end
  
  # Сохраняем алиасы поиска для будущего использования в системе поиска шин
  # Эти данные будут использованы при создании car_tire_configurations
  brand.update_column(:search_aliases, brand_data[:search_aliases]) if brand.respond_to?(:search_aliases)
end

puts "\n📊 Статистика создания брендов:"
puts "  🆕 Создано новых брендов: #{brands_created}"
puts "  🔄 Обновлено существующих: #{brands_updated}"
puts "  📋 Всего брендов в системе: #{CarBrand.count}"

# Создаем индекс для быстрого поиска по алиасам (если поддерживается)
if ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
  begin
    ActiveRecord::Base.connection.execute(
      "CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_car_brands_search_aliases 
       ON car_brands USING GIN ((search_aliases::text))"
    )
    puts "  🔍 Создан индекс для поиска по алиасам брендов"
  rescue => e
    puts "  ⚠️ Не удалось создать индекс для алиасов: #{e.message}"
  end
end

puts "✅ Обработанные бренды автомобилей успешно загружены!"
puts "   Система поиска шин готова к работе с #{CarBrand.count} брендами автомобилей"