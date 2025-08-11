#!/usr/bin/env ruby
# Тест полного диалога с группировкой: Зимние шины + размер

require_relative '../../config/environment'

puts "🧪 Тестирование полного диалога с группировкой"
puts "=" * 60

# Создаем экземпляр сервиса
service = TireChatService.new(
  conversation_history: [], 
  current_filters: {}, 
  user_preferences: {}, 
  locale: 'ru'
)

puts "\n1️⃣ Первое сообщение: 'Зимние шины' (быстрый вопрос)"
response1 = service.process_message("Зимние шины", nil, is_quick_question: true)
puts "   Ответ: #{response1[:message][0..150]}..."
puts "   Фильтры после 1-го сообщения: #{service.instance_variable_get(:@current_filters)}"

puts "\n2️⃣ Второе сообщение: '195 65 на 15'"
response2 = service.process_message("195 65 на 15", nil, is_quick_question: false)
puts "   Ответ: #{response2[:message][0..200]}..."
puts "   Фильтры после 2-го сообщения: #{service.instance_variable_get(:@current_filters)}"

# Проверяем есть ли рекомендации
if response2[:recommendations] && response2[:recommendations].any?
  puts "\n🎯 Рекомендации найдены: #{response2[:recommendations].length}"
  
  response2[:recommendations].first(3).each_with_index do |rec, index|
    product = rec[:product]
    puts "   #{index + 1}. #{product.brand_normalized} #{product.original_model} - #{product.formatted_price}"
  end
else
  puts "\n❌ Рекомендации не найдены"
  
  # Попробуем получить их напрямую
  puts "\n🔍 Пробуем получить рекомендации напрямую..."
  direct_recommendations = service.send(:get_tire_recommendations)
  puts "   Прямой запрос: #{direct_recommendations.length} рекомендаций"
  
  if direct_recommendations.any?
    direct_recommendations.first(3).each_with_index do |rec, index|
      product = rec[:product]
      puts "      #{index + 1}. #{product.brand_normalized} #{product.original_model} - #{product.formatted_price}"
    end
  end
end

puts "\n" + "=" * 60
puts "🎯 Тестирование завершено"