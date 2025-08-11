#!/usr/bin/env ruby
# Тест проблемы с сохранением фильтров после рекомендаций

require_relative '../../config/environment'

puts '🔍 ДИАГНОСТИКА ПРОБЛЕМЫ С СОХРАНЕНИЕМ ФИЛЬТРОВ'
puts '=' * 60

service = TireChatService.new(locale: 'uk')

puts "\n🎯 СЦЕНАРИЙ ПОЛЬЗОВАТЕЛЯ:"
puts "1. Преміум шини → 215 55 17 лето → получает рекомендации"
puts "2. Порекомендуй мне шины на тигуан → должен начать новый поиск"
puts

# Шаг 1: Полный флоу премиум шин
puts "1️⃣ ЭТАП 1: ПРЕМИУМ ШИНЫ 215/55R17 ЛЕТО"
puts '=' * 50

response1 = service.process_message('Преміум шини', nil, is_quick_question: true)
puts "✓ Шаг 1.1: Премиум шины"

response2 = service.process_message('215 55 17 лето', nil)
puts "✓ Шаг 1.2: Размер + сезон + рекомендации"
puts "✓ Action: #{response2[:action]}"
puts "✓ Recommendations: #{response2[:recommendations]&.count || 0}"

# Состояние после первого этапа
puts "\n📊 СОСТОЯНИЕ ПОСЛЕ ПЕРВОГО ЭТАПА:"
filters_after_recommendations = service.instance_variable_get(:@current_filters)
preferences_after_recommendations = service.instance_variable_get(:@user_preferences)

puts "Фильтры: #{filters_after_recommendations}"
puts "Предпочтения: #{preferences_after_recommendations}"

# Шаг 2: Новый запрос
puts "\n2️⃣ ЭТАП 2: НОВЫЙ ЗАПРОС 'ШИНЫ НА ТИГУАН'"
puts '=' * 50

response3 = service.process_message('порекомендуй мне шины на тигуан', nil)
puts "✓ Ответ на новый запрос"
puts "✓ Action: #{response3[:action]}"

# Состояние после нового запроса
puts "\n📊 СОСТОЯНИЕ ПОСЛЕ НОВОГО ЗАПРОСА:"
filters_after_new_request = service.instance_variable_get(:@current_filters)
preferences_after_new_request = service.instance_variable_get(:@user_preferences)

puts "Фильтры: #{filters_after_new_request}"
puts "Предпочтения: #{preferences_after_new_request}"

# Анализ результата
puts "\n🔍 АНАЛИЗ ПРОБЛЕМЫ:"
puts '=' * 40

# Проверяем сохранились ли старые фильтры
old_size_preserved = filters_after_new_request[:size] == filters_after_recommendations[:size]
old_season_preserved = filters_after_new_request[:season] == filters_after_recommendations[:season]
old_price_segment_preserved = preferences_after_new_request[:price_segment] == preferences_after_recommendations[:price_segment]

puts "Размер сохранился: #{old_size_preserved ? '❌ ДА (плохо)' : '✅ НЕТ (хорошо)'}"
puts "Сезон сохранился: #{old_season_preserved ? '❌ ДА (плохо)' : '✅ НЕТ (хорошо)'}"
puts "Ценовой сегмент сохранился: #{old_price_segment_preserved ? '❌ ДА (плохо)' : '✅ НЕТ (хорошо)'}"

# Проверяем содержимое ответа
puts "\nСодержимое ответа:"
if response3[:message].include?('215/55R17')
  puts "❌ ПРОБЛЕМА: ответ содержит старый размер 215/55R17"
else
  puts "✅ ХОРОШО: ответ не содержит старый размер"
end

if response3[:message].include?('Tiguan') || response3[:message].include?('тигуан')
  puts "✅ ХОРОШО: ответ упоминает Tiguan"
else
  puts "❌ ПРОБЛЕМА: ответ не упоминает Tiguan"
end

# Проверяем тип ответа
case response3[:action]
when 'show_price_segment_recommendations', 'show_recommendations_with_options'
  puts "❌ ПРОБЛЕМА: система показывает готовые рекомендации вместо запроса параметров"
when 'car_model_detected', 'car_search_suggested'
  puts "✅ ХОРОШО: система распознала автомобиль и предложила поиск по авто"
else
  puts "⚠️  НЕОПРЕДЕЛЕННО: action = #{response3[:action]}"
end

puts "\n🎯 ВЕРДИКТ:"
puts '=' * 30

if old_size_preserved || old_season_preserved || old_price_segment_preserved
  puts "❌ ПРОБЛЕМА ПОДТВЕРЖДЕНА: старые фильтры сохраняются"
  puts "   Нужно очищать состояние после выдачи рекомендаций"
else
  puts "✅ ПРОБЛЕМА НЕ ВОСПРОИЗВЕДЕНА: фильтры корректно очищаются"
end

puts "\n📝 РЕКОМЕНДУЕМОЕ РЕШЕНИЕ:"
puts "   После выдачи рекомендаций очищать @current_filters и @user_preferences"
puts "   Либо добавить детекцию 'нового поиска' по ключевым словам"