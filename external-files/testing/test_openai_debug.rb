#!/usr/bin/env ruby
# Тест OpenAI парсинга для отладки

require_relative '../../config/environment'

puts "🧪 Тест OpenAI парсинга запроса 'для тайоты шины на 17'"
puts "=" * 60

# Проверяем доступность OpenAI
puts "🔧 Проверка конфигурации:"
puts "- LLM доступен: #{OpenaiService.available?}"
puts "- API ключ есть: #{SystemSetting.get_value('openai_api_key').present?}"
puts "- LLM включен: #{SystemSetting.get_value('tire_search_enable_llm')}"
puts

# Создаем сервис и тестируем
service = OpenaiService.new
query = "для тайоты шины на 17"

puts "🤖 Тестируем парсинг запроса: '#{query}'"
puts "-" * 40

begin
  result = service.parse_tire_search_query(query)
  puts "✅ Результат парсинга:"
  puts result.inspect
  puts
  
  if result.empty?
    puts "❌ LLM вернул пустой результат"
  else
    puts "✅ LLM успешно распарсил:"
    result.each do |key, value|
      puts "  - #{key}: #{value}"
    end
  end
  
rescue => e
  puts "❌ Ошибка: #{e.message}"
  puts e.backtrace.first(5)
end

puts
puts "🏁 Тест завершен"