#!/usr/bin/env ruby
# Тест точного сценария "самые дорогие шины" без размера

require_relative '../../config/environment'

puts "🧪 Тест сценария: Пользователь просит 'самые дорогие шины' без указания размера"
puts "=" * 80

# Создаем экземпляр сервиса
service = TireChatService.new(
  conversation_history: [], 
  current_filters: {}, 
  user_preferences: {}, 
  locale: 'ru'
)

puts "\n👤 Пользователь: 'самые дорогие шины'"
response1 = service.process_message("самые дорогие шины", nil, is_quick_question: false)
puts "🤖 Ответ: #{response1[:message]}"
puts "🔧 Предпочтения: #{response1[:preferences_updated]}"

# Проверяем, что система правильно распознала премиум сегмент и запросила размер
premium_recognized = response1[:preferences_updated]&.dig(:price_segment) == 'premium'
size_requested = response1[:message].include?('Размер шин')

puts "🔍 Проверки:"
puts "   Премиум сегмент распознан: #{premium_recognized ? '✅' : '❌'}"
puts "   Размер запрошен: #{size_requested ? '✅' : '❌'}"

if premium_recognized && size_requested
  puts "✅ ПРАВИЛЬНО: Система распознала премиум сегмент и запросила размер"
else
  puts "❌ ОШИБКА: Система не запросила размер или не распознала премиум сегмент"
end

puts "\n" + "=" * 80

# Тест с уже имеющимся размером и сезоном
puts "\n🔍 ТЕСТ 2: Добавление размера к уже установленному премиум сегменту"
service_with_context = TireChatService.new(
  conversation_history: [], 
  current_filters: {
    size: { width: 195, height: 65, diameter: 15, full_size: '195/65R15' },
    season: 'winter'
  }, 
  user_preferences: { price_segment: 'premium' }, 
  locale: 'ru'
)

puts "\n👤 При уже заданных фильтрах (195/65R15 зимние) + премиум сегмент"
puts "🤖 Ищем рекомендации автоматически..."

recommendations = service_with_context.send(:get_price_segment_recommendations, nil, 'premium')
puts "📊 Найдено рекомендаций: #{recommendations.length}"

if recommendations.any?
  puts "\n💰 Топ-3 самых дорогих:"
  recommendations.first(3).each_with_index do |rec, index|
    product = rec[:product]
    puts "   #{index + 1}. #{product.brand_normalized} #{product.original_model} - #{product.formatted_price}"
  end
  
  # Проверяем, что это действительно премиум шины
  prices = recommendations.map { |rec| rec[:product].price_uah.to_f }
  avg_price = prices.sum / prices.length
  puts "\n📈 Средняя цена: #{avg_price.round(0)} грн"
  
  if avg_price > 2000
    puts "✅ ПРЕМИУМ СЕГМЕНТ: Средняя цена превышает 2000 грн"
  else
    puts "⚠️ ВНИМАНИЕ: Средняя цена ниже ожидаемой для премиум сегмента"
  end
end

puts "\n" + "=" * 80
puts "🎯 Тестирование завершено"