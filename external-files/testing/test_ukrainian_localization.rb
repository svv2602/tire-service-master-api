#!/usr/bin/env ruby
# Тест украинской локализации для ценовых сегментов

require_relative '../../config/environment'

puts "🧪 Тестирование украинской локализации ценовых сегментов"
puts "=" * 70

# Тест на украинском языке
puts "\n🇺🇦 УКРАИНСКИЙ ЯЗЫК (locale: 'uk')"
service_uk = TireChatService.new(
  conversation_history: [], 
  current_filters: {}, 
  user_preferences: {}, 
  locale: 'uk'
)

puts "\n👤 Пользователь: 'дешеві на літо'"
response1 = service_uk.process_message("дешеві на літо", nil, is_quick_question: false)
puts "🤖 Ответ:"
puts response1[:message]
puts "🔍 Анализ:"
puts "   Содержит украинские слова: #{response1[:message].include?('розмір') ? '✅' : '❌'}"
puts "   Запрашивает размер: #{response1[:message].include?('Розмір шин') ? '✅' : '❌'}"

puts "\n" + "-" * 50

# Тест на русском языке для сравнения
puts "\n🇷🇺 РУССКИЙ ЯЗЫК (locale: 'ru')"
service_ru = TireChatService.new(
  conversation_history: [], 
  current_filters: {}, 
  user_preferences: {}, 
  locale: 'ru'
)

puts "\n👤 Пользователь: 'дешевые на лето'"
response2 = service_ru.process_message("дешевые на лето", nil, is_quick_question: false)
puts "🤖 Ответ:"
puts response2[:message]
puts "🔍 Анализ:"
puts "   Содержит русские слова: #{response2[:message].include?('размер') ? '✅' : '❌'}"
puts "   Запрашивает размер: #{response2[:message].include?('Размер шин') ? '✅' : '❌'}"

puts "\n" + "=" * 70

# Полный диалог на украинском
puts "\n🇺🇦 ПОЛНЫЙ ДИАЛОГ НА УКРАИНСКОМ:"
full_service = TireChatService.new(
  conversation_history: [], 
  current_filters: {}, 
  user_preferences: {}, 
  locale: 'uk'
)

puts "\n1️⃣ 'дешеві шини'"
resp1 = full_service.process_message("дешеві шини", nil, is_quick_question: false)
puts "   #{resp1[:message][0..100]}..."

puts "\n2️⃣ '195 65 на 15'"
resp2 = full_service.process_message("195 65 на 15", nil, is_quick_question: false) 
puts "   #{resp2[:message][0..100]}..."

puts "\n3️⃣ 'літні'"
resp3 = full_service.process_message("літні", nil, is_quick_question: false)
puts "   #{resp3[:message][0..150]}..."

if resp3[:recommendations]
  puts "\n📊 Рекомендации получены: #{resp3[:recommendations].length} шт."
  
  # Проверяем украинские тексты в рекомендациях
  message = resp3[:message]
  ukraine_indicators = [
    'найдоступніші за ціною',
    'постачальників', 
    'Економія до',
    'Найкраща ціна',
    'Економічний вибір'
  ]
  
  found_indicators = ukraine_indicators.select { |indicator| message.include?(indicator) }
  puts "🔍 Найдены украинские индикаторы: #{found_indicators.join(', ')}"
  puts "✅ Локализация работает: #{found_indicators.any? ? 'ДА' : 'НЕТ'}"
else
  puts "❌ Рекомендации не получены"
end

puts "\n" + "=" * 70
puts "🎯 Тестирование завершено"