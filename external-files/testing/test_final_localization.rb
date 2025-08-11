#!/usr/bin/env ruby
# Финальный тест украинской локализации

require_relative '../../config/environment'

puts "🧪 Финальный тест украинской локализации"
puts "=" * 60

# Тест сценария из пользовательского запроса
service = TireChatService.new(
  conversation_history: [], 
  current_filters: {}, 
  user_preferences: {}, 
  locale: 'uk'
)

puts "\n🇺🇦 Тест запроса: 'дешеві на літо'"
response = service.process_message("дешеві на літо", nil, is_quick_question: false)

puts "\n📝 АНАЛИЗ ОТВЕТА:"
puts response[:message]

# Проверка ключевых элементов украинской локализации
checks = {
  'Принято на украинском' => response[:message].include?('Прийнято'),
  'Летние шины на украинском' => response[:message].include?('літні шини'),
  'Бюджетные причины' => response[:message].include?('Найкраща ціна') && response[:message].include?('Економічний вибір'),
  'Объяснение сегмента' => response[:message].include?('найдоступніші за ціною'),
  'Поставщики на украинском' => response[:message].include?('постачальників'),
  'Диалоговые кнопки' => response[:message].include?('Що ви хочете зробити'),
  'НЕТ русских слов' => !response[:message].include?('шины размера') && !response[:message].include?('Показаны')
}

puts "\n🔍 РЕЗУЛЬТАТЫ ПРОВЕРКИ:"
checks.each do |check, result|
  status = result ? '✅' : '❌'
  puts "   #{status} #{check}"
end

overall_success = checks.values.all?
puts "\n🎯 ОБЩИЙ РЕЗУЛЬТАТ: #{overall_success ? '✅ УСПЕХ' : '❌ ЕСТЬ ПРОБЛЕМЫ'}"

if overall_success
  puts "\n🎉 Локализация работает идеально!"
else
  puts "\n⚠️ Найденные проблемы требуют дополнительного внимания."
end

puts "\n" + "=" * 60