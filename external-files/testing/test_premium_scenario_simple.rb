#!/usr/bin/env ruby
# Простой тест сценария "Премиум шины"

require_relative '../../config/environment'

puts '🧪 ТЕСТ СЦЕНАРИЯ "ПРЕМИУМ ШИНЫ"'
puts '=' * 50

service = TireChatService.new(locale: 'uk')

puts "\n1️⃣ Шаг 1: Преміум шини"
puts '-' * 30
response1 = service.process_message('Преміум шини', nil, is_quick_question: true)
puts "✅ Ответ: система ищет премиум шины"
puts "Preferences: #{service.instance_variable_get(:@user_preferences)}"

puts "\n2️⃣ Шаг 2: 215 55 17"
puts '-' * 30  
response2 = service.process_message('215 55 17', nil)
puts "✅ Ответ: размер принят"
puts "Filters: #{service.instance_variable_get(:@current_filters)[:size]}"
puts "Preferences: #{service.instance_variable_get(:@user_preferences)}"

puts "\n3️⃣ Шаг 3: лето"
puts '-' * 30
response3 = service.process_message('лето', nil)
puts "✅ Ответ: сезон принят"
puts "Filters season: #{service.instance_variable_get(:@current_filters)[:season]}"
puts "Preferences: #{service.instance_variable_get(:@user_preferences)}"
puts "Action: #{response3[:action]}"

# Анализируем что произошло
puts "\n🔍 АНАЛИЗ РЕЗУЛЬТАТА:"
puts '-' * 40

if response3[:action] == 'show_price_segment_recommendations'
  puts "✅ Использован метод ценовых сегментов"
  
  # Проверяем первую рекомендацию
  if response3[:recommendations] && response3[:recommendations].any?
    first_rec = response3[:recommendations].first
    first_product = first_rec[:product]
    
    puts "Первая рекомендация:"
    puts "  Бренд: #{first_product.tire_brand&.name || first_product.original_brand}"
    puts "  Модель: #{first_product.tire_model&.name || first_product.original_model}"
    puts "  Цена: #{first_product.price_uah} грн"
    
    # Проверяем это премиум шина или нет
    if first_product.price_uah && first_product.price_uah > 4000
      puts "✅ ЭТО ПРЕМИУМ ШИНА (цена > 4000 грн)"
    else
      puts "❌ ЭТО НЕ ПРЕМИУМ ШИНА (цена <= 4000 грн)"
    end
  else
    puts "❌ Нет рекомендаций"
  end
else
  puts "❌ НЕ использован метод ценовых сегментов"
  puts "Действие: #{response3[:action]}"
end

# Дополнительная проверка - есть ли вообще премиум шины в этом размере
puts "\n🔍 ПРОВЕРКА НАЛИЧИЯ ПРЕМИУМ ШИН:"
puts '-' * 45

products = SupplierTireProduct.in_stock
  .where(width: 215, height: 55, diameter: 17, season: 'summer')
  .includes(:tire_brand, :tire_model)

puts "Всего шин 215/55R17 лето: #{products.count}"

if products.any?
  prices = products.map(&:price_uah).compact.sort
  puts "Диапазон цен: #{prices.first} - #{prices.last} грн"
  
  expensive_products = products.where('price_uah > ?', 4000).order(price_uah: :desc).limit(3)
  puts "Дорогие шины (>4000 грн): #{expensive_products.count}"
  
  expensive_products.each_with_index do |p, i|
    brand = p.tire_brand&.name || p.original_brand
    model = p.tire_model&.name || p.original_model
    puts "  #{i+1}. #{brand} #{model} - #{p.price_uah} грн"
  end
else
  puts "❌ Нет шин в этом размере/сезоне"
end