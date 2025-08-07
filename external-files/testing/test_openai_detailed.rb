#!/usr/bin/env ruby
# Детальный тест OpenAI с логированием каждого шага

require_relative '../../config/environment'

puts "🧪 Детальный тест OpenAI для запроса 'для тайоты шины на 17'"
puts "=" * 70

# Создаем сервис напрямую
service = OpenaiService.new

# Получаем клиент
client = service.instance_variable_get(:@client)
if client.nil?
  puts "❌ OpenAI клиент не инициализирован"
  exit 1
end

query = "для тайоты шины на 17"
puts "📝 Запрос: '#{query}'"
puts

# Формируем промпт
prompt = OpenaiService::TIRE_SEARCH_PROMPT + query
puts "🤖 Промпт для OpenAI:"
puts "-" * 40
puts prompt
puts "-" * 40
puts

# Выполняем запрос к OpenAI
begin
  puts "⏳ Отправляем запрос к OpenAI..."
  
  response = client.chat(
    parameters: {
      model: service.send(:openai_model),
      messages: [
        {
          role: "user",
          content: prompt
        }
      ],
      max_tokens: service.send(:openai_max_tokens),
      temperature: service.send(:openai_temperature)
    }
  )
  
  puts "✅ Ответ получен!"
  puts
  
  # Извлекаем контент
  content = response.dig("choices", 0, "message", "content")
  puts "📄 Raw ответ от OpenAI:"
  puts "-" * 40
  puts content
  puts "-" * 40
  puts
  
  if content.nil? || content.empty?
    puts "❌ Пустой ответ от OpenAI"
    exit 1
  end
  
  # Пробуем парсить JSON
  begin
    parsed = JSON.parse(content)
    puts "✅ JSON успешно распарсен:"
    puts parsed.inspect
    puts
    
    # Проверяем валидацию
    cleaned = service.send(:validate_and_clean_result, parsed)
    puts "🧹 Результат после валидации:"
    puts cleaned.inspect
    puts
    
    if cleaned.empty?
      puts "❌ Результат пустой после валидации"
      puts "🔍 Анализ полей:"
      parsed.each do |key, value|
        puts "  - #{key}: #{value.inspect} (#{value.class})"
      end
    else
      puts "✅ Валидация прошла успешно"
    end
    
  rescue JSON::ParserError => e
    puts "❌ Ошибка парсинга JSON: #{e.message}"
    puts "Raw content: #{content}"
  end
  
rescue => e
  puts "❌ Ошибка запроса к OpenAI: #{e.message}"
  puts e.backtrace.first(3)
end

puts
puts "🏁 Тест завершен"