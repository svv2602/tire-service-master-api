# frozen_string_literal: true

# Тест автоматической нормализации при загрузке прайса
puts "🧪 ТЕСТИРОВАНИЕ АВТОМАТИЧЕСКОЙ НОРМАЛИЗАЦИИ"
puts "=" * 60

# Проверяем наличие поставщика для тестирования
supplier = Supplier.first
unless supplier
  puts "❌ Нет поставщиков для тестирования"
  exit
end

puts "🏢 Тестируем с поставщиком: #{supplier.name} (ID: #{supplier.id})"

# Статистика ДО нормализации
total_products = supplier.supplier_tire_products.count
products_without_brand = supplier.supplier_tire_products.where(tire_brand_id: nil).count
products_without_country = supplier.supplier_tire_products.where(country_id: nil).count
products_without_score = supplier.supplier_tire_products.where(optimality_score: nil).count

puts "\n📊 СТАТИСТИКА ДО НОРМАЛИЗАЦИИ:"
puts "  📦 Всего товаров: #{total_products}"
puts "  🏷️ Без бренда: #{products_without_brand}"
puts "  🌍 Без страны: #{products_without_country}"
puts "  🎯 Без рейтинга: #{products_without_score}"

if products_without_brand.zero? && products_without_country.zero? && products_without_score.zero?
  puts "✅ Все товары уже нормализованы!"
  puts "\n💡 Для тестирования обнулим некоторые связи..."
  
  # Обнуляем связи у первых 10 товаров для демонстрации
  test_products = supplier.supplier_tire_products.limit(10)
  test_products.update_all(tire_brand_id: nil, country_id: nil, optimality_score: nil)
  
  puts "🔄 Обнулены связи у 10 товаров для демонстрации"
end

# Тестируем автоматическую нормализацию через процессор
puts "\n🔄 ЗАПУСК АВТОМАТИЧЕСКОЙ НОРМАЛИЗАЦИИ..."

# Создаем экземпляр процессора
processor = SupplierXmlProcessor.new(supplier, '<test/>')

# Запускаем только нормализацию
start_time = Time.current
normalization_result = processor.send(:run_auto_normalization)
duration = Time.current - start_time

puts "\n📈 РЕЗУЛЬТАТЫ НОРМАЛИЗАЦИИ:"
puts "  ⏱️ Время выполнения: #{(duration * 1000).round(2)}мс"
puts "  📦 Обработано товаров: #{normalization_result[:processed]}"
puts "  🏷️ Нормализовано брендов: #{normalization_result[:normalized_brands]}"
puts "  🌍 Нормализовано стран: #{normalization_result[:normalized_countries]}"
puts "  🚗 Нормализовано моделей: #{normalization_result[:normalized_models]}"
puts "  ❌ Ошибок: #{normalization_result[:failed]}"
puts "  💬 Резюме: #{normalization_result[:summary]}"

# Статистика ПОСЛЕ нормализации
puts "\n📊 СТАТИСТИКА ПОСЛЕ НОРМАЛИЗАЦИИ:"
total_after = supplier.supplier_tire_products.count
with_brand_after = supplier.supplier_tire_products.where.not(tire_brand_id: nil).count
with_country_after = supplier.supplier_tire_products.where.not(country_id: nil).count
with_score_after = supplier.supplier_tire_products.where.not(optimality_score: nil).count

puts "  📦 Всего товаров: #{total_after}"
puts "  🏷️ С брендом: #{with_brand_after} (#{percentage(with_brand_after, total_after)}%)"
puts "  🌍 Со страной: #{with_country_after} (#{percentage(with_country_after, total_after)}%)"
puts "  🎯 С рейтингом: #{with_score_after} (#{percentage(with_score_after, total_after)}%)"

# Примеры нормализованных товаров
puts "\n🔍 ПРИМЕРЫ НОРМАЛИЗОВАННЫХ ТОВАРОВ:"
supplier.supplier_tire_products
        .joins(:tire_brand)
        .includes(:tire_brand, :country)
        .limit(5)
        .each_with_index do |product, index|
  country_name = product.country&.name || "не определена"
  puts "  #{index + 1}. #{product.tire_brand.name} #{product.original_model}"
  puts "     Страна: #{country_name}, Рейтинг: #{product.optimality_score}"
end

puts "\n✅ ТЕСТИРОВАНИЕ ЗАВЕРШЕНО!"

def percentage(part, total)
  return 0 if total.zero?
  (part.to_f / total * 100).round(1)
end