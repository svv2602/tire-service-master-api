#!/usr/bin/env ruby
# Тест исправления распознавания размеров шин в TireChatService

require_relative '../../config/environment'

# Тестовые случаи
test_cases = [
  {
    input: "195 65 на 15",
    expected_type: "size_request",
    expected_size: "195/65R15",
    description: "Размер с 'на'"
  },
  {
    input: "195/65R15", 
    expected_type: "size_request",
    expected_size: "195/65R15",
    description: "Стандартный формат"
  },
  {
    input: "205 55 16",
    expected_type: "size_request", 
    expected_size: "205/55R16",
    description: "Размер через пробелы"
  },
  {
    input: "шины на мазда 6",
    expected_type: "car_model_request",
    expected_car: "mazda 6",
    description: "Модель автомобиля"
  },
  {
    input: "зимние шины 195 65 на 15",
    expected_type: "size_request", # размер должен иметь приоритет
    expected_size: "195/65R15",
    description: "Сезон + размер"
  }
]

puts "🧪 Тестирование исправления распознавания размеров шин"
puts "=" * 60

service = TireChatService.new(conversation_history: [], current_filters: {}, user_preferences: {}, locale: 'ru')

test_cases.each_with_index do |test_case, index|
  puts "\n#{index + 1}. #{test_case[:description]}: '#{test_case[:input]}'"
  
  begin
    # Используем приватный метод через send
    result = service.send(:analyze_simple_intent, test_case[:input])
    
    puts "   Результат: #{result}"
    
    if test_case[:expected_type] == "size_request"
      if result[:parameters][:size] == test_case[:expected_size]
        puts "   ✅ УСПЕХ: Размер распознан корректно"
      else
        puts "   ❌ ОШИБКА: Ожидался #{test_case[:expected_size]}, получен #{result[:parameters][:size]}"
      end
    elsif test_case[:expected_type] == "car_model_request"
      if result[:parameters][:car_model]&.include?(test_case[:expected_car].split.last)
        puts "   ✅ УСПЕХ: Модель автомобиля распознана"
      else
        puts "   ❌ ОШИБКА: Ожидалась модель с '#{test_case[:expected_car]}', получена #{result[:parameters][:car_model]}"
      end
    end
    
  rescue => e
    puts "   💥 ИСКЛЮЧЕНИЕ: #{e.message}"
  end
end

puts "\n" + "=" * 60
puts "🎯 Тестирование завершено"