#!/usr/bin/env ruby
# Тест локализации кнопки каталога

require_relative '../../config/environment'

puts "🧪 Тест локализации кнопки каталога"
puts "=" * 60

# Тест на украинском
puts "\n🇺🇦 УКРАИНСКИЙ ЯЗЫК"
service_uk = TireChatService.new(
  conversation_history: [], 
  current_filters: {}, 
  user_preferences: {}, 
  locale: 'uk'
)

puts "\n1. 'літні шини'"
response1 = service_uk.process_message("літні шини", nil, is_quick_question: true)

puts "\n2. '215 55 на 16'"
response2 = service_uk.process_message("215 55 на 16", nil, is_quick_question: false)

if response2[:catalog_button]
  puts "✅ Кнопка каталога найдена"
  puts "📝 Текст кнопки: #{response2[:catalog_button][:text]}"
  
  # Проверяем украинский текст
  ukrainian_words = ['Показати', 'варіанти', 'Літні']
  found_ukrainian = ukrainian_words.any? { |word| response2[:catalog_button][:text].include?(word) }
  puts "🇺🇦 Содержит украинские слова: #{found_ukrainian ? '✅' : '❌'}"
  
  # Проверяем что НЕТ русских слов
  russian_words = ['Показать', 'варианты', 'Летние']
  found_russian = russian_words.any? { |word| response2[:catalog_button][:text].include?(word) }
  puts "🇷🇺 НЕ содержит русские слова: #{found_russian ? '❌' : '✅'}"
else
  puts "❌ Кнопка каталога не найдена"
end

# Также проверим в сообщении
if response2[:message].include?("Ви можете також переглянути")
  puts "✅ Текст в сообщении тоже на украинском"
else
  puts "❌ Текст в сообщении не на украинском"
end

puts "\n" + "-" * 40

# Тест на русском для сравнения
puts "\n🇷🇺 РУССКИЙ ЯЗЫК"
service_ru = TireChatService.new(
  conversation_history: [], 
  current_filters: {}, 
  user_preferences: {}, 
  locale: 'ru'
)

puts "\n1. 'летние шины'"
response3 = service_ru.process_message("летние шины", nil, is_quick_question: true)

puts "\n2. '215 55 на 16'"
response4 = service_ru.process_message("215 55 на 16", nil, is_quick_question: false)

if response4[:catalog_button]
  puts "✅ Кнопка каталога найдена"
  puts "📝 Текст кнопки: #{response4[:catalog_button][:text]}"
  
  # Проверяем русский текст
  russian_words = ['Показать', 'варианты', 'Летние']
  found_russian = russian_words.any? { |word| response4[:catalog_button][:text].include?(word) }
  puts "🇷🇺 Содержит русские слова: #{found_russian ? '✅' : '❌'}"
else
  puts "❌ Кнопка каталога не найдена"
end

puts "\n" + "=" * 60
puts "🎯 Тестирование завершено"