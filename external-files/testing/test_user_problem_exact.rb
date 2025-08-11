#!/usr/bin/env ruby
# Тест точного сценария проблемы пользователя

require_relative '../../config/environment'

puts '🎯 ТЕСТ ТОЧНОГО СЦЕНАРИЯ ПОЛЬЗОВАТЕЛЯ'
puts '=' * 50

service = TireChatService.new(locale: 'uk')

puts "\n📱 ЭМУЛЯЦИЯ ТОЧНОГО СЦЕНАРИЯ ПОЛЬЗОВАТЕЛЯ:"
puts "1. Быстрый вопрос: Преміум шини"
puts "2. Ввод: 215 55 17 лето"
puts

# Шаг 1: Быстрый вопрос
puts "1️⃣ Преміум шини (быстрый вопрос)"
puts '-' * 40
response1 = service.process_message('Преміум шини', nil, is_quick_question: true)
puts response1[:message]
puts "✓ Preferences: #{service.instance_variable_get(:@user_preferences)}"

# Шаг 2: Размер + сезон в одном сообщении (как делал пользователь)
puts "\n2️⃣ 215 55 17 лето"
puts '-' * 40
response2 = service.process_message('215 55 17 лето', nil)
puts response2[:message]
puts
puts "✓ Final preferences: #{service.instance_variable_get(:@user_preferences)}"
puts "✓ Final filters: #{service.instance_variable_get(:@current_filters)}"
puts "✓ Action: #{response2[:action]}"

# Анализ результата
puts "\n🔍 АНАЛИЗ РЕЗУЛЬТАТА:"
puts '=' * 50

if response2[:recommendations] && response2[:recommendations].any?
  puts "📦 Найдено рекомендаций: #{response2[:recommendations].count}"
  
  response2[:recommendations].each_with_index do |rec, i|
    product = rec[:product]
    brand = product.tire_brand&.name || product.original_brand
    model = product.tire_model&.name || product.original_model
    price = product.price_uah
    
    puts "#{i+1}. #{brand} #{model} - #{price} грн"
    
    # Проверяем премиум или нет
    if price && price > 4000
      puts "   ✅ ПРЕМИУМ (> 4000 грн)"
    else
      puts "   ❌ НЕ ПРЕМИУМ (<= 4000 грн)"
    end
  end
  
  # Общая оценка
  premium_count = response2[:recommendations].count do |rec|
    price = rec[:product].price_uah
    price && price > 4000
  end
  
  puts "\n📊 ИТОГ:"
  puts "   Всего рекомендаций: #{response2[:recommendations].count}"
  puts "   Премиум шин: #{premium_count}"
  puts "   Бюджетных шин: #{response2[:recommendations].count - premium_count}"
  
  if premium_count > response2[:recommendations].count / 2
    puts "   ✅ РЕЗУЛЬТАТ: Большинство рекомендаций - ПРЕМИУМ"
  else
    puts "   ❌ РЕЗУЛЬТАТ: Большинство рекомендаций - НЕ ПРЕМИУМ"
  end
  
  # Проверяем первую рекомендацию (самую важную)
  first_price = response2[:recommendations].first[:product].price_uah
  if first_price && first_price > 4000
    puts "   ✅ ПЕРВАЯ РЕКОМЕНДАЦИЯ: ПРЕМИУМ"
  else
    puts "   ❌ ПЕРВАЯ РЕКОМЕНДАЦИЯ: НЕ ПРЕМИУМ"
  end
else
  puts "❌ НЕТ РЕКОМЕНДАЦИЙ"
end

# Финальная проверка
puts "\n🎯 ВЕРДИКТ:"
puts '=' * 30

if response2[:action] == 'show_price_segment_recommendations'
  puts "✅ Используется ценовой сегмент"
  
  if response2[:recommendations] && response2[:recommendations].any?
    first_price = response2[:recommendations].first[:product].price_uah
    if first_price && first_price > 4000
      puts "✅ ПРОБЛЕМА РЕШЕНА: показываются премиум шины"
    else
      puts "❌ ПРОБЛЕМА НЕ РЕШЕНА: показываются бюджетные шины"
    end
  else
    puts "❌ НЕТ РЕКОМЕНДАЦИЙ"
  end
else
  puts "❌ НЕ используется ценовой сегмент"
  puts "❌ ПРОБЛЕМА НЕ РЕШЕНА"
end