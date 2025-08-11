#!/usr/bin/env ruby
# Тест системы ценовых сегментов

require_relative '../../config/environment'

puts "🧪 Тестирование системы ценовых сегментов"
puts "=" * 60

# Создаем экземпляр сервиса
service = TireChatService.new(
  conversation_history: [], 
  current_filters: {}, 
  user_preferences: {}, 
  locale: 'ru'
)

puts "\n🔍 ТЕСТ 1: Запрос 'самые дорогие шины'"
response1 = service.process_message("самые дорогие шины", nil, is_quick_question: false)
puts "   Ответ: #{response1[:message][0..150]}..."
puts "   Тип действия: #{response1[:action]}"
puts "   Сегмент: #{response1[:preferences_updated]&.dig(:price_segment)}"

puts "\n🔍 ТЕСТ 2: Добавляем размер '195 65 на 15'"
response2 = service.process_message("195 65 на 15", nil, is_quick_question: false)
puts "   Ответ: #{response2[:message][0..150]}..."
puts "   Фильтры: #{service.instance_variable_get(:@current_filters)}"

puts "\n🔍 ТЕСТ 3: Добавляем сезон 'зимние'"
response3 = service.process_message("зимние", nil, is_quick_question: false)
puts "   Ответ: #{response3[:message][0..200]}..."

if response3[:recommendations]
  puts "\n📊 АНАЛИЗ РЕКОМЕНДАЦИЙ:"
  puts "   Количество: #{response3[:recommendations].length}"
  
  response3[:recommendations].each_with_index do |rec, index|
    product = rec[:product]
    puts "   #{index + 1}. #{product.brand_normalized} #{product.original_model} - #{product.formatted_price}"
  end
  
  # Проверяем сортировку (для премиум должна быть по убыванию цены)
  prices = response3[:recommendations].map { |rec| rec[:product].price_uah.to_f }
  is_sorted_desc = prices == prices.sort.reverse
  puts "\n   Сортировка по убыванию цены: #{is_sorted_desc ? '✅' : '❌'}"
  puts "   Цены: #{prices.join(', ')}"
  
  if response3[:catalog_button]
    puts "\n   ✅ Кнопка каталога найдена: #{response3[:catalog_button][:text]}"
  else
    puts "\n   ❌ Кнопка каталога не найдена"
  end
else
  puts "\n   ❌ Рекомендации не найдены"
end

puts "\n" + "=" * 60

puts "\n🔍 ТЕСТ 4: Новый запрос - 'дешевые шины 205/55R16 летние'"
service_budget = TireChatService.new(
  conversation_history: [], 
  current_filters: {}, 
  user_preferences: {}, 
  locale: 'ru'
)

response4 = service_budget.process_message("дешевые шины 205/55R16 летние", nil, is_quick_question: false)
puts "   Ответ: #{response4[:message][0..200]}..."

if response4[:recommendations]
  puts "\n📊 АНАЛИЗ БЮДЖЕТНЫХ РЕКОМЕНДАЦИЙ:"
  puts "   Количество: #{response4[:recommendations].length}"
  
  response4[:recommendations].each_with_index do |rec, index|
    product = rec[:product]
    puts "   #{index + 1}. #{product.brand_normalized} #{product.original_model} - #{product.formatted_price}"
  end
  
  # Проверяем сортировку (для бюджетных должна быть по возрастанию цены)
  prices = response4[:recommendations].map { |rec| rec[:product].price_uah.to_f }
  is_sorted_asc = prices == prices.sort
  puts "\n   Сортировка по возрастанию цены: #{is_sorted_asc ? '✅' : '❌'}"
  puts "   Цены: #{prices.join(', ')}"
else
  puts "\n   ❌ Рекомендации не найдены"
end

puts "\n" + "=" * 60
puts "🎯 Тестирование завершено"