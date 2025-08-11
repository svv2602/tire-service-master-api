#!/usr/bin/env ruby
# Тест конкретной проблемы пользователя

require_relative '../../config/environment'

puts '🎯 ТЕСТ КОНКРЕТНОЙ ПРОБЛЕМЫ ПОЛЬЗОВАТЕЛЯ'
puts '=' * 50

service = TireChatService.new(locale: 'uk')

# Эмулируем быстрый вопрос "Недорогие шины"
puts 'Быстрый вопрос: "Недорогі шини"'
puts '-' * 30

response = service.process_message('Недорогі шини', nil, is_quick_question: true)

puts 'Ответ системы:'
puts response[:message]
puts
puts 'Детали:'
puts "  Действие: #{response[:action]}"
puts "  Следующий шаг: #{response[:next_step]}"

# Проверяем правильность
if response[:message].include?('бюджетні') && !response[:message].include?('преміум')
  puts "\n✅ ПРОБЛЕМА РЕШЕНА: система правильно распознала 'недорогі' как 'бюджетні'"
else
  puts "\n❌ ПРОБЛЕМА НЕ РЕШЕНА: система все еще неправильно распознает запрос"
end

puts "\n" + "=" * 50
puts "🔍 ДОПОЛНИТЕЛЬНАЯ ДИАГНОСТИКА:"

# Анализ намерений
intent = service.send(:analyze_simple_intent, 'Недорогі шини')
puts "Тип намерения: #{intent[:type]}"
puts "Параметры: #{intent[:parameters]}"

# Какой ценовой сегмент был определен?
if intent[:parameters][:price_segment]
  segment = intent[:parameters][:price_segment]
  puts "Ценовой сегмент: #{segment}"
  
  case segment
  when 'budget'
    puts "✅ Правильно: недорогие = бюджетные"
  when 'premium'
    puts "❌ Неправильно: недорогие ≠ премиум"
  when 'middle'
    puts "⚠️  Приемлемо: недорогие = средний сегмент"
  end
else
  puts "❌ Ценовой сегмент не определен"
end