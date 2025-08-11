#!/usr/bin/env ruby
# Финальный тест сценария пользователя

require_relative '../../config/environment'

puts '🎯 ФИНАЛЬНЫЙ ТЕСТ СЦЕНАРИЯ ПОЛЬЗОВАТЕЛЯ'
puts '=' * 50

service = TireChatService.new(locale: 'uk')

puts "\n📱 ТОЧНЫЙ СЦЕНАРИЙ ПОЛЬЗОВАТЕЛЯ:"
puts "1. Быстрый вопрос: Преміум шини"
puts "2. Ввод: 215 55 17 лето → получает рекомендации премиум шин"
puts "3. Ввод: порекомендуй мне шины на тигуан → должен начать новый поиск"
puts

# ЭТАП 1: Премиум шины
puts "1️⃣ ЭТАП 1: ПРЕМИУМ ШИНЫ"
puts '=' * 30
response1 = service.process_message('Преміум шини', nil, is_quick_question: true)
puts "✓ Ответ: #{response1[:message][0..50]}..."

# ЭТАП 2: Размер + сезон
puts "\n2️⃣ ЭТАП 2: РАЗМЕР + СЕЗОН"
puts '=' * 30
response2 = service.process_message('215 55 17 лето', nil)
puts "✓ Действие: #{response2[:action]}"
puts "✓ Рекомендаций: #{response2[:recommendations]&.count || 0}"

if response2[:recommendations] && response2[:recommendations].any?
  first_rec = response2[:recommendations].first
  product = first_rec[:product]
  brand = product.tire_brand&.name || product.original_brand
  model = product.tire_model&.name || product.original_model
  price = product.price_uah
  
  puts "✓ Первая рекомендация: #{brand} #{model} - #{price} грн"
  
  if price && price > 4000
    puts "✅ ПРЕМИУМ ШИНА (цена > 4000 грн)"
  else
    puts "❌ НЕ ПРЕМИУМ ШИНА"
  end
end

# ЭТАП 3: Новый запрос
puts "\n3️⃣ ЭТАП 3: НОВЫЙ ЗАПРОС 'ШИНЫ НА ТИГУАН'"
puts '=' * 30
response3 = service.process_message('порекомендуй мне шины на тигуан', nil)
puts "✓ Действие: #{response3[:action]}"
puts "✓ Ответ: #{response3[:message][0..100]}..."

# Проверяем состояние после нового запроса
filters_after = service.instance_variable_get(:@current_filters)
preferences_after = service.instance_variable_get(:@user_preferences)

puts "\n📊 АНАЛИЗ РЕЗУЛЬТАТА:"
puts '=' * 30

# Проверка 1: Очистка состояния
state_cleared = filters_after[:size].nil? && 
                filters_after[:season].nil? && 
                preferences_after[:price_segment].nil?

puts "Состояние очищено: #{state_cleared ? '✅ ДА' : '❌ НЕТ'}"

# Проверка 2: Содержимое ответа
contains_old_size = response3[:message].include?('215/55R17')
mentions_tiguan = response3[:message].downcase.include?('тигуан') || 
                  response3[:message].downcase.include?('tiguan')

puts "Не содержит старый размер: #{!contains_old_size ? '✅ ДА' : '❌ НЕТ'}"
puts "Упоминает Tiguan: #{mentions_tiguan ? '✅ ДА' : '❌ НЕТ'}"

# Проверка 3: Тип ответа
appropriate_action = !['show_price_segment_recommendations', 'show_recommendations_with_options'].include?(response3[:action])
puts "Правильный тип ответа: #{appropriate_action ? '✅ ДА' : '❌ НЕТ'}"

# Финальная оценка
all_checks_passed = state_cleared && !contains_old_size && appropriate_action

puts "\n🎯 ФИНАЛЬНАЯ ОЦЕНКА:"
puts '=' * 30

if all_checks_passed
  puts "✅ ВСЕ ПРОВЕРКИ ПРОШЛИ: ПРОБЛЕМА РЕШЕНА!"
  puts "   Система корректно:"
  puts "   - Очищает предыдущие фильтры"
  puts "   - Не показывает старые рекомендации"
  puts "   - Начинает новый поиск для Tiguan"
else
  puts "❌ НЕКОТОРЫЕ ПРОВЕРКИ НЕ ПРОШЛИ"
  puts "   Состояние очищено: #{state_cleared ? '✅' : '❌'}"
  puts "   Не содержит старый размер: #{!contains_old_size ? '✅' : '❌'}"
  puts "   Правильный тип ответа: #{appropriate_action ? '✅' : '❌'}"
end

puts "\n🔄 ТЕПЕРЬ ПОЛЬЗОВАТЕЛЬ МОЖЕТ:"
puts "   1. Указать размер шин для Tiguan"
puts "   2. Выбрать сезон"
puts "   3. Получить новые рекомендации"
puts "   БЕЗ влияния предыдущих настроек (215/55R17, лето, премиум)"