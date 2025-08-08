# frozen_string_literal: true

# Скрипт для анализа данных шин и создания сидов
puts '=== АНАЛИЗ ДАННЫХ ДЛЯ СИДОВ ==='

# Общая статистика
puts "\n📊 ОБЩАЯ СТАТИСТИКА:"
puts "SupplierTireProduct: #{SupplierTireProduct.count} записей"
puts "Countries: #{Country.count} записей" 
puts "TireBrands: #{TireBrand.count} записей"
puts "TireModels: #{TireModel.count} записей"

# Анализ брендов
puts "\n🏷️ АНАЛИЗ БРЕНДОВ:"
brands = SupplierTireProduct.distinct.pluck(:original_brand).compact.sort.reject(&:blank?)
puts "Всего уникальных брендов: #{brands.size}"
puts "Топ-10 брендов:"
brand_counts = SupplierTireProduct.group(:original_brand).count.sort_by { |_, count| -count }
brand_counts.first(10).each_with_index do |(brand, count), idx|
  puts "  #{idx + 1}. #{brand} (#{count} товаров)"
end

# Анализ стран
puts "\n🌍 АНАЛИЗ СТРАН:"
countries = SupplierTireProduct.distinct.pluck(:original_country).compact.sort.reject(&:blank?)
puts "Всего уникальных стран: #{countries.size}"
puts "Страны: #{countries.join(', ')}"

# Анализ моделей
puts "\n🚗 АНАЛИЗ МОДЕЛЕЙ:"
models = SupplierTireProduct.distinct.pluck(:original_model).compact.sort.reject(&:blank?)
puts "Всего уникальных моделей: #{models.size}"
puts "Первые 15 моделей: #{models.first(15).join(', ')}"

# Анализ сезонности
puts "\n❄️ АНАЛИЗ СЕЗОННОСТИ:"
seasons = SupplierTireProduct.group(:season).count
seasons.each { |season, count| puts "  #{season}: #{count} товаров" }

# Топ комбинации бренд-модель
puts "\n🔝 ТОП-10 КОМБИНАЦИЙ БРЕНД-МОДЕЛЬ:"
combinations = SupplierTireProduct
  .group(:original_brand, :original_model)
  .count
  .sort_by { |_, count| -count }
  .first(10)

combinations.each_with_index do |((brand, model), count), idx|
  puts "  #{idx + 1}. #{brand} #{model} (#{count} товаров)"
end

puts "\n✅ АНАЛИЗ ЗАВЕРШЕН"