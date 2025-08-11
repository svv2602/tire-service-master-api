#!/usr/bin/env ruby
# Диагностика проблемы с премиум рекомендациями

require_relative '../../config/environment'

puts '🔍 ДИАГНОСТИКА ПРОБЛЕМЫ С ПРЕМИУМ РЕКОМЕНДАЦИЯМИ'
puts '=' * 60

service = TireChatService.new(locale: 'uk')

puts "\n1. Тестируем: 'Преміум шини'"
puts '-' * 40

# Шаг 1: Премиум шины
response1 = service.process_message('Преміум шини', nil, is_quick_question: true)
puts "Ответ 1: #{response1[:message][0..100]}..."
puts "Действие 1: #{response1[:action]}"
puts "user_preferences после шага 1: #{service.instance_variable_get(:@user_preferences)}"

puts "\n2. Тестируем: '215 55 17'"
puts '-' * 40

# Шаг 2: Размер
response2 = service.process_message('215 55 17', nil)
puts "Ответ 2: #{response2[:message][0..100]}..."
puts "Действие 2: #{response2[:action]}"
puts "current_filters после шага 2: #{service.instance_variable_get(:@current_filters)}"
puts "user_preferences после шага 2: #{service.instance_variable_get(:@user_preferences)}"

puts "\n3. Тестируем: 'лето'"
puts '-' * 40

# Шаг 3: Сезон + рекомендации
response3 = service.process_message('лето', nil)
puts "Ответ 3: #{response3[:message][0..200]}..."
puts "Действие 3: #{response3[:action]}"

# Проверяем какие рекомендации были сгенерированы
if response3[:recommendations]
  puts "\n🎯 АНАЛИЗ РЕКОМЕНДАЦИЙ:"
  response3[:recommendations].each_with_index do |rec, i|
    puts "  #{i+1}. #{rec[:brand]} #{rec[:model]} - #{rec[:price]} грн"
    puts "     Рейтинг: #{rec[:optimality_score]}"
    puts "     Причины: #{rec[:recommendation_reasons]}"
  end
end

puts "\n🔍 СОСТОЯНИЕ СЕРВИСА:"
puts "user_preferences: #{service.instance_variable_get(:@user_preferences)}"
puts "current_filters: #{service.instance_variable_get(:@current_filters)}"

# Попробуем прямо вызвать получение премиум рекомендаций
puts "\n🧪 ПРЯМОЙ ТЕСТ ПРЕМИУМ РЕКОМЕНДАЦИЙ:"
puts '-' * 50

# Проверим что есть в базе данных для этого размера и сезона
products = SupplierTireProduct.includes(:tire_brand, :tire_model)
  .where("size_width = ? AND size_height = ? AND size_diameter = ? AND season = ?", 
         215, 55, 17, 'summer')

puts "Всего продуктов 215/55R17 лето: #{products.count}"

if products.any?
  prices = products.map(&:price).compact.sort
  puts "Цены: #{prices.first} - #{prices.last} грн"
  
  # Попробуем получить премиум рекомендации напрямую
  premium_recs = service.send(:get_price_segment_recommendations, products, 'premium')
  puts "Премиум рекомендаций: #{premium_recs.count}"
  
  premium_recs.each_with_index do |rec, i|
    puts "  #{i+1}. #{rec[:brand]} #{rec[:model]} - #{rec[:price]} грн"
  end
else
  puts "❌ Нет продуктов для размера 215/55R17 лето"
end