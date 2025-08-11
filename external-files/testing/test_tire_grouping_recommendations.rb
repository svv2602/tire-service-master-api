#!/usr/bin/env ruby
# Тест группировки рекомендаций шин в TireChatService

require_relative '../../config/environment'

puts "🧪 Тестирование группировки рекомендаций шин"
puts "=" * 60

# Создаем экземпляр сервиса
service = TireChatService.new(
  conversation_history: [], 
  current_filters: {
    size: { width: 195, height: 65, diameter: 15, full_size: "195/65R15" },
    season: 'winter'
  }, 
  user_preferences: { priority_type: 'price_quality' }, 
  locale: 'ru'
)

puts "\n🔍 Поиск зимних шин размера 195/65R15..."

begin
  # Получаем рекомендации
  recommendations = service.send(:get_tire_recommendations)
  
  puts "\n📊 Результаты:"
  puts "   Найдено рекомендаций: #{recommendations.length}"
  
  if recommendations.any?
    puts "\n🎯 Топ-рекомендации:"
    
    recommendations.each_with_index do |rec, index|
      product = rec[:product]
      score = rec[:optimality_score]
      suppliers_count = rec[:suppliers_count] || 1
      price_savings = rec[:price_savings] || 0
      
      puts "\n#{index + 1}. #{product.brand_normalized} #{product.original_model}"
      puts "   Размер: #{product.width}/#{product.height}R#{product.diameter} #{product.load_index}#{product.speed_index}"
      puts "   Цена: #{product.formatted_price}"
      puts "   Рейтинг: #{score.round(1)}/10"
      puts "   Поставщиков: #{suppliers_count}"
      puts "   Экономия: #{price_savings} грн" if price_savings > 0
      puts "   Причины: #{rec[:recommendation_reasons]&.join(', ')}"
    end
    
    puts "\n📝 Форматированный ответ для пользователя:"
    puts "=" * 40
    formatted_response = service.send(:format_recommendations, recommendations)
    puts formatted_response
    
  else
    puts "   ❌ Рекомендации не найдены"
  end
  
rescue => e
  puts "💥 ОШИБКА: #{e.message}"
  puts "Трассировка:"
  puts e.backtrace.first(5).join("\n")
end

puts "\n" + "=" * 60
puts "🎯 Тестирование завершено"