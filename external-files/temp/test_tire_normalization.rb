# frozen_string_literal: true

# Скрипт для тестирования нормализации шин
puts "🧪 ТЕСТИРОВАНИЕ НОРМАЛИЗАЦИИ ШИН"
puts "=" * 50

# Проверка справочников
puts "\n📚 ПРОВЕРКА СПРАВОЧНИКОВ:"
puts "Countries: #{Country.count}"
puts "TireBrands: #{TireBrand.count}"
puts "TireModels: #{TireModel.count}"

if Country.count.zero? || TireBrand.count.zero?
  puts "❌ Справочники пусты! Запустите: rails db:seed"
  exit
end

# Тестирование поиска брендов
puts "\n🏷️ ТЕСТИРОВАНИЕ ПОИСКА БРЕНДОВ:"
test_brands = [
  "Michelin",
  "MICHELIN", 
  "michelin",
  "Мишлен",
  "Continental",
  "Грельандер", # Должен найти Grenlander через алиасы
  "Kleber"
]

test_brands.each do |brand_name|
  found_brand = TireBrand.find_by_name_or_alias(brand_name)
  if found_brand
    puts "  ✅ #{brand_name} -> #{found_brand.name} (рейтинг: #{found_brand.rating_score})"
  else
    puts "  ❌ #{brand_name} -> НЕ НАЙДЕН"
  end
end

# Тестирование поиска стран
puts "\n🌍 ТЕСТИРОВАНИЕ ПОИСКА СТРАН:"
test_countries = [
  "Германия",
  "Germany", 
  "Франция",
  "France",
  "Китай",
  "China"
]

test_countries.each do |country_name|
  found_country = Country.find_by_name_or_alias(country_name)
  if found_country
    puts "  ✅ #{country_name} -> #{found_country.name} (рейтинг: #{found_country.rating_score})"
  else
    puts "  ❌ #{country_name} -> НЕ НАЙДЕНА"
  end
end

# Тестирование нормализации конкретных товаров
puts "\n🔄 ТЕСТИРОВАНИЕ НОРМАЛИЗАЦИИ ТОВАРОВ:"

# Берем первые 5 товаров без нормализации
test_products = SupplierTireProduct
  .where(tire_brand_id: nil, tire_model_id: nil, country_id: nil)
  .limit(5)

if test_products.empty?
  puts "  ℹ️ Нет товаров для тестирования (все уже нормализованы)"
else
  service = TireNormalizationService.new
  
  test_products.each do |product|
    puts "\n  📦 Товар ID #{product.id}: #{product.original_brand} #{product.original_model}"
    puts "     Страна: #{product.original_country}"
    
    # Делаем копию для тестирования
    test_product = product.dup
    
    # Тестируем нормализацию
    service.normalize_product(test_product)
    
    if test_product.tire_brand_id
      brand = TireBrand.find(test_product.tire_brand_id)
      puts "     ✅ Бренд найден: #{brand.name} (рейтинг: #{brand.rating_score})"
    else
      puts "     ❌ Бренд не найден"
    end
    
    if test_product.country_id
      country = Country.find(test_product.country_id)
      puts "     ✅ Страна найдена: #{country.name} (рейтинг: #{country.rating_score})"
    else
      puts "     ❌ Страна не найдена"
    end
    
    if test_product.optimality_score
      puts "     🎯 Рейтинг оптимальности: #{test_product.optimality_score}"
    end
  end
end

# Статистика покрытия нормализации
puts "\n📊 СТАТИСТИКА ПОКРЫТИЯ:"
total_products = SupplierTireProduct.count
with_brand = SupplierTireProduct.where.not(tire_brand_id: nil).count
with_country = SupplierTireProduct.where.not(country_id: nil).count

puts "  📦 Всего товаров: #{total_products}"
puts "  🏷️ С нормализованным брендом: #{with_brand} (#{percentage(with_brand, total_products)}%)"
puts "  🌍 С нормализованной страной: #{with_country} (#{percentage(with_country, total_products)}%)"

# Топ не найденных брендов
puts "\n🔍 ТОП-5 НЕ НАЙДЕННЫХ БРЕНДОВ:"
not_found_brands = SupplierTireProduct
  .where(tire_brand_id: nil)
  .group(:original_brand)
  .count
  .sort_by { |_, count| -count }
  .first(5)

not_found_brands.each_with_index do |(brand, count), index|
  puts "  #{index + 1}. #{brand} (#{count} товаров)"
end

def percentage(part, total)
  return 0 if total.zero?
  (part.to_f / total * 100).round(1)
end

puts "\n✅ ТЕСТИРОВАНИЕ ЗАВЕРШЕНО!"