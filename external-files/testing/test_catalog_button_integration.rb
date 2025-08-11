#!/usr/bin/env ruby
# Тест интеграции кнопки каталога в чате

require_relative '../../config/environment'

puts "🧪 Тестирование интеграции кнопки каталога"
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
puts "   Ответ: #{response1[:message][0..100]}..."
puts "   Кнопка каталога: #{response1[:catalog_button] ? 'НЕТ (ожидается)' : 'НЕТ (корректно)'}"

puts "\n2️⃣ Второе сообщение: '195 65 на 15'"
response2 = service.process_message("195 65 на 15", nil, is_quick_question: false)
puts "   Ответ: #{response2[:message][0..150]}..."

if response2[:catalog_button]
  puts "   ✅ Кнопка каталога найдена!"
  puts "   Текст кнопки: #{response2[:catalog_button][:text]}"
  puts "   Фильтры:"
  response2[:catalog_button][:filters].each do |key, value|
    puts "     #{key}: #{value}"
  end
  puts "   Действие: #{response2[:catalog_button][:action]}"
else
  puts "   ❌ Кнопка каталога не найдена"
end

puts "\n🔍 Содержимое ответа содержит кнопку каталога?"
if response2[:message].include?("Вы можете также просмотреть все размеры")
  puts "   ✅ Да, текст кнопки найден в сообщении"
else
  puts "   ❌ Текст кнопки не найден в сообщении"
end

puts "\n📊 Рекомендации:"
if response2[:recommendations] && response2[:recommendations].any?
  puts "   ✅ Найдено #{response2[:recommendations].length} рекомендаций"
  response2[:recommendations].first(3).each_with_index do |rec, index|
    product = rec[:product]
    puts "   #{index + 1}. #{product.brand_normalized} #{product.original_model} - #{product.formatted_price}"
  end
else
  puts "   ❌ Рекомендации не найдены"
end

puts "\n" + "=" * 60
puts "🎯 Тестирование завершено"