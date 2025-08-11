#!/usr/bin/env ruby
# Тест руководства по выбору размера шин

require_relative '../../config/environment'

puts "🧪 Тестирование руководства по выбору размера шин"
puts "=" * 70

# Тест на русском языке
puts "\n🇷🇺 РУССКИЙ ЯЗЫК"
service_ru = TireChatService.new(
  conversation_history: [], 
  current_filters: {}, 
  user_preferences: {}, 
  locale: 'ru'
)

puts "\n👤 Пользователь: 'Какой размер выбрать?'"
response_ru = service_ru.process_message("Какой размер выбрать?", nil, is_quick_question: true)

puts "\n📝 ОТВЕТ:"
puts response_ru[:message]

puts "\n🔍 АНАЛИЗ РУССКОГО ОТВЕТА:"
ru_checks = {
  'Есть заголовок' => response_ru[:message].include?('Как выбрать правильный размер'),
  'Есть инструкция поиска' => response_ru[:message].include?('боковине покрышки'),
  'Есть расшифровка' => response_ru[:message].include?('195** - ширина шины'),
  'Есть популярные размеры' => response_ru[:message].include?('195/65R15') && response_ru[:message].include?('компактные автомобили'),
  'Есть раздел о поиске по авто' => response_ru[:message].include?('Не знаете размер?'),
  'Есть призыв к действию' => response_ru[:message].include?('Введите размер шин')
}

ru_checks.each do |check, result|
  status = result ? '✅' : '❌'
  puts "   #{status} #{check}"
end

puts "\n" + "-" * 50

# Тест на украинском языке
puts "\n🇺🇦 УКРАИНСКИЙ ЯЗЫК"
service_uk = TireChatService.new(
  conversation_history: [], 
  current_filters: {}, 
  user_preferences: {}, 
  locale: 'uk'
)

puts "\n👤 Пользователь: 'Який розмір обрати?'"
response_uk = service_uk.process_message("Який розмір обрати?", nil, is_quick_question: true)

puts "\n📝 ОТВЕТ:"
puts response_uk[:message]

puts "\n🔍 АНАЛИЗ УКРАИНСКОГО ОТВЕТА:"
uk_checks = {
  'Есть заголовок' => response_uk[:message].include?('Як обрати правильний розмір'),
  'Есть инструкция поиска' => response_uk[:message].include?('боковині покришки'),
  'Есть расшифровка' => response_uk[:message].include?('195** - ширина шини'),
  'Есть популярные размеры' => response_uk[:message].include?('195/65R15') && response_uk[:message].include?('компактні автомобілі'),
  'Есть раздел о поиске по авто' => response_uk[:message].include?('Не знаєте розмір?'),
  'Есть призыв к действию' => response_uk[:message].include?('Введіть розмір шин')
}

uk_checks.each do |check, result|
  status = result ? '✅' : '❌'
  puts "   #{status} #{check}"
end

# Общая оценка
all_checks_passed = (ru_checks.values + uk_checks.values).all?
puts "\n🎯 ОБЩИЙ РЕЗУЛЬТАТ: #{all_checks_passed ? '✅ ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ' : '❌ ЕСТЬ ПРОБЛЕМЫ'}"

puts "\n" + "=" * 70
puts "🎯 Тестирование завершено"