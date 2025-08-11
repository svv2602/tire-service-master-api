#!/usr/bin/env ruby
# Тест улучшенной интеграции OpenAI в чате

require_relative '../../config/environment'

puts "🧪 ТЕСТИРОВАНИЕ УЛУЧШЕННОЙ ИНТЕГРАЦИИ OPENAI"
puts "=" * 70

# Тестовые запросы разных типов
test_cases = [
  {
    message: "сравни модели бриджестоун близак 6 и мишлен альпин 6",
    expected_openai: true,
    description: "Сравнение моделей шин"
  },
  {
    message: "особливості конкретних моделей",
    expected_openai: true,
    description: "Вопрос об особенностях"
  },
  {
    message: "что лучше для города - continental или michelin",
    expected_openai: true,
    description: "Сравнение брендов для города"
  },
  {
    message: "чем отличается nokian от continental",
    expected_openai: true,
    description: "Отличия между брендами"
  },
  {
    message: "какие характеристики важнее для зимних шин?",
    expected_openai: true,
    description: "Технический вопрос с вопросительным знаком"
  },
  {
    message: "посоветуй хорошие шины",
    expected_openai: true,
    description: "Запрос совета"
  },
  {
    message: "расскажи про технологии в шинах",
    expected_openai: true,
    description: "Вопрос про технологии"
  },
  {
    message: "что можете посоветовать?",
    expected_openai: true,
    description: "Общий вопросительный запрос"
  },
  {
    message: "помоги выбрать шины для toyota",
    expected_openai: true,
    description: "Помощь в выборе с автомобилем"
  },
  {
    message: "195/65R15",
    expected_openai: false,
    description: "Простой размер шин"
  }
]

results = []
service = TireChatService.new(locale: 'uk')

test_cases.each_with_index do |test_case, i|
  puts "\n#{i+1}. #{test_case[:description]}"
  puts "   Запрос: \"#{test_case[:message]}\""
  
  # Проверяем распознавание
  should_use = service.send(:should_use_openai_for_chat?, test_case[:message])
  puts "   Должен использовать OpenAI: #{should_use ? '✅' : '❌'}"
  
  # Проверяем анализ намерений
  intent = service.send(:analyze_user_intent, test_case[:message])
  puts "   Тип намерения: #{intent[:type]}"
  
  # Тестируем полный процесс
  response = service.process_message(test_case[:message], nil)
  is_openai_response = response[:action] == 'openai_response'
  puts "   Использовал OpenAI: #{is_openai_response ? '✅' : '❌'}"
  
  # Проверяем ожидания
  expectation_met = (test_case[:expected_openai] == is_openai_response)
  puts "   Ожидание выполнено: #{expectation_met ? '✅' : '❌'}"
  
  if is_openai_response
    puts "   Длина ответа: #{response[:message].length} символов"
  end
  
  results << {
    test: test_case[:description],
    expected: test_case[:expected_openai],
    actual: is_openai_response,
    passed: expectation_met,
    intent_type: intent[:type]
  }
  
  puts "   " + "-" * 50
end

# Подсчет результатов
passed = results.count { |r| r[:passed] }
total = results.count
openai_used = results.count { |r| r[:actual] }

puts "\n" + "=" * 70
puts "📊 РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ:"
puts "   Всего тестов: #{total}"
puts "   Прошли: #{passed} (#{(passed.to_f / total * 100).round(1)}%)"
puts "   Использовали OpenAI: #{openai_used} тестов"
puts

# Детальная статистика
puts "📈 ДЕТАЛЬНАЯ СТАТИСТИКА:"
results.each do |result|
  status = result[:passed] ? "✅" : "❌"
  puts "   #{status} #{result[:test]}"
  if !result[:passed]
    puts "     Ожидалось: #{result[:expected] ? 'OpenAI' : 'Стандартный'}"
    puts "     Получено: #{result[:actual] ? 'OpenAI' : 'Стандартный'} (#{result[:intent_type]})"
  end
end

overall_success = passed.to_f / total >= 0.8
puts "\n🎯 ОБЩИЙ РЕЗУЛЬТАТ: #{overall_success ? '✅ УСПЕШНО' : '❌ ТРЕБУЕТ ДОРАБОТКИ'}"

puts "\n" + "=" * 70
puts "🎯 Тестирование завершено"