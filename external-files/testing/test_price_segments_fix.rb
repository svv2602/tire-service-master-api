#!/usr/bin/env ruby
# Тестирование исправлений ценовых сегментов

require_relative '../../config/environment'

puts '🧪 ТЕСТИРОВАНИЕ ИСПРАВЛЕНИЙ ЦЕНОВЫХ СЕГМЕНТОВ'
puts '=' * 55

service = TireChatService.new(locale: 'uk')

test_cases = [
  {
    message: 'недорогі шини',
    expected: 'budget',
    description: 'Недорогие шины (украинский)'
  },
  {
    message: 'недорогие шины',
    expected: 'budget', 
    description: 'Недорогие шины (русский)'
  },
  {
    message: 'дешевые шины',
    expected: 'budget',
    description: 'Дешевые шины'
  },
  {
    message: 'дешеві шини',
    expected: 'budget',
    description: 'Дешевые шины (украинский)'
  },
  {
    message: 'бюджетные шины',
    expected: 'budget',
    description: 'Бюджетные шины'
  },
  {
    message: 'бюджетні шини',
    expected: 'budget',
    description: 'Бюджетные шины (украинский)'
  },
  {
    message: 'дорогие шины',
    expected: 'premium',
    description: 'Дорогие шины'
  },
  {
    message: 'дорогі шини',
    expected: 'premium',
    description: 'Дорогие шины (украинский)'
  },
  {
    message: 'премиум шины',
    expected: 'premium',
    description: 'Премиум шины'
  },
  {
    message: 'преміум шини',
    expected: 'premium',
    description: 'Премиум шины (украинский)'
  },
  {
    message: 'средние шины',
    expected: 'middle',
    description: 'Средние шины'
  },
  {
    message: 'середні шини',
    expected: 'middle',
    description: 'Средние шины (украинский)'
  }
]

results = []

test_cases.each_with_index do |test_case, i|
  puts "\n#{i+1}. #{test_case[:description]}"
  puts "   Сообщение: \"#{test_case[:message]}\""
  
  intent = service.send(:analyze_simple_intent, test_case[:message])
  actual_segment = intent[:parameters][:price_segment]
  
  puts "   Ожидается: #{test_case[:expected]}"
  puts "   Получено: #{actual_segment}"
  
  success = (actual_segment == test_case[:expected])
  puts "   Результат: #{success ? '✅ УСПЕХ' : '❌ ОШИБКА'}"
  
  results << {
    test: test_case[:description],
    expected: test_case[:expected],
    actual: actual_segment,
    success: success
  }
end

passed = results.count { |r| r[:success] }
total = results.count

puts "\n" + '=' * 55
puts "📊 ИТОГОВЫЕ РЕЗУЛЬТАТЫ:"
puts "   Всего тестов: #{total}"
puts "   Прошли успешно: #{passed}"
puts "   Процент успеха: #{(passed.to_f / total * 100).round(1)}%"

if passed < total
  puts "\n❌ НЕУДАЧНЫЕ ТЕСТЫ:"
  results.select { |r| !r[:success] }.each do |result|
    puts "   • #{result[:test]}: ожидалось '#{result[:expected]}', получено '#{result[:actual]}'"
  end
end

overall_success = passed == total
puts "\n🎯 ОБЩИЙ РЕЗУЛЬТАТ: #{overall_success ? '✅ ВСЕ ИСПРАВЛЕНО' : '❌ ТРЕБУЮТСЯ ДОРАБОТКИ'}"