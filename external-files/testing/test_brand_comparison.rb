#!/usr/bin/env ruby
# Тест сравнения брендов шин

require_relative '../../config/environment'

puts "🧪 Тестирование сравнения брендов шин"
puts "=" * 70

# Тест на русском языке
puts "\n🇷🇺 РУССКИЙ ЯЗЫК"
service_ru = TireChatService.new(
  conversation_history: [], 
  current_filters: {}, 
  user_preferences: {}, 
  locale: 'ru'
)

puts "\n👤 Пользователь: 'Сравнить бренды'"
response_ru = service_ru.process_message("Сравнить бренды", nil, is_quick_question: true)

puts "\n📝 ОТВЕТ:"
puts response_ru[:message]

puts "\n🔍 АНАЛИЗ РУССКОГО ОТВЕТА:"
ru_checks = {
  'Есть заголовок' => response_ru[:message].include?('Сравнение брендов шин'),
  'Есть введение о важности' => response_ru[:message].include?('влияет на качество'),
  'Есть премиум бренды' => response_ru[:message].include?('Премиум сегмент') && response_ru[:message].include?('Nokian'),
  'Есть средний сегмент' => response_ru[:message].include?('Средний сегмент') && response_ru[:message].include?('Fulda'),
  'Есть бюджетный сегмент' => response_ru[:message].include?('Бюджетный сегмент') && response_ru[:message].include?('Росава'),
  'Есть рекомендации по выбору' => response_ru[:message].include?('Как выбрать?'),
  'Есть конкретные советы' => response_ru[:message].include?('Для максимальной безопасности'),
  'Есть призыв к действию' => response_ru[:message].include?('Назовите ваш бюджет')
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

puts "\n👤 Пользователь: 'Порівняти бренди'"
response_uk = service_uk.process_message("Порівняти бренди", nil, is_quick_question: true)

puts "\n📝 ОТВЕТ:"
puts response_uk[:message]

puts "\n🔍 АНАЛИЗ УКРАИНСКОГО ОТВЕТА:"
uk_checks = {
  'Есть заголовок' => response_uk[:message].include?('Порівняння брендів шин'),
  'Есть введение о важности' => response_uk[:message].include?('впливає на якість'),
  'Есть премиум бренды' => response_uk[:message].include?('Преміум сегмент') && response_uk[:message].include?('Nokian'),
  'Есть средний сегмент' => response_uk[:message].include?('Середній сегмент') && response_uk[:message].include?('Fulda'),
  'Есть бюджетный сегмент' => response_uk[:message].include?('Бюджетний сегмент') && response_uk[:message].include?('Росава'),
  'Есть рекомендации по выбору' => response_uk[:message].include?('Як обрати?'),
  'Есть конкретные советы' => response_uk[:message].include?('Для максимальної безпеки'),
  'Есть призыв к действию' => response_uk[:message].include?('Назвіть ваш бюджет')
}

uk_checks.each do |check, result|
  status = result ? '✅' : '❌'
  puts "   #{status} #{check}"
end

# Проверка содержания брендов
puts "\n🏷️ ПРОВЕРКА БРЕНДОВ:"
brand_checks = {
  'Премиум: Nokian' => response_ru[:message].include?('Nokian') && response_ru[:message].include?('Финляндия'),
  'Премиум: Michelin' => response_ru[:message].include?('Michelin') && response_ru[:message].include?('Франция'),
  'Премиум: Continental' => response_ru[:message].include?('Continental') && response_ru[:message].include?('Германия'),
  'Средний: Barum' => response_ru[:message].include?('Barum') && response_ru[:message].include?('Чехия'),
  'Бюджетный: Росава' => response_ru[:message].include?('Росава') && response_ru[:message].include?('Украина'),
  'Бюджетный: Кама' => response_ru[:message].include?('Кама') && response_ru[:message].include?('Россия')
}

brand_checks.each do |check, result|
  status = result ? '✅' : '❌'
  puts "   #{status} #{check}"
end

# Общая оценка
all_checks_passed = (ru_checks.values + uk_checks.values + brand_checks.values).all?
puts "\n🎯 ОБЩИЙ РЕЗУЛЬТАТ: #{all_checks_passed ? '✅ ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ' : '❌ ЕСТЬ ПРОБЛЕМЫ'}"

puts "\n" + "=" * 70
puts "🎯 Тестирование завершено"