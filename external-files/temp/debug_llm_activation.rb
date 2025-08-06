#!/usr/bin/env ruby
# Тест для отладки активации LLM

require_relative '../../config/environment'

puts "🔍 Тестируем активацию LLM для запроса 'Посоветуй мне шины на тильду'..."
puts

query = "Посоветуй мне шины на тильду"
options = {
  limit: 20,
  offset: 0,
  use_llm: true,
  locale: "ru",
  context: {}
}

puts "Запрос: #{query}"
puts "Опции: #{options.inspect}"
puts

# Создаем экземпляр TireSearchService
service = TireSearchService.new(query, options)
puts "Создан TireSearchService"

# Получаем приватные данные
parsed_data = service.instance_variable_get(:@parsed_data)
use_llm = service.instance_variable_get(:@use_llm)

puts "use_llm параметр: #{use_llm}"
puts "parsed_data после parse_simple_query: #{parsed_data.inspect}"

# Проверяем логику needs_llm_parsing? пошагово
puts
puts "🧪 Проверяем логику needs_llm_parsing?..."

brand_blank = parsed_data[:brand].blank?
model_blank = parsed_data[:model].blank?

puts "brand.blank? = #{brand_blank} (значение: #{parsed_data[:brand].inspect})"
puts "model.blank? = #{model_blank} (значение: #{parsed_data[:model].inspect})"

if brand_blank || model_blank
  puts "✅ Условие (brand.blank? || model.blank?) = true"
  
  # Проверяем diameter_only_query
  diameter_only_query = query.strip.match?(/^(шины\s+)?(r?\d{2,3}|на\s+\d{2,3})$/i)
  puts "diameter_only_query = #{diameter_only_query}"
  
  diameter_present = parsed_data[:diameter].present?
  puts "diameter.present? = #{diameter_present} (значение: #{parsed_data[:diameter].inspect})"
  
  if diameter_present && brand_blank && model_blank && diameter_only_query
    puts "❌ LLM НЕ нужен: найден только диаметр без других слов"
  else
    # Проверяем частичные размеры шин
    partial_tire_size = (parsed_data[:width].present? && parsed_data[:height].present?) ||
                       (parsed_data[:width].present? && parsed_data[:diameter].present?) ||
                       (parsed_data[:height].present? && parsed_data[:diameter].present?)
    
    puts "partial_tire_size = #{partial_tire_size}"
    puts "  width: #{parsed_data[:width].inspect}"
    puts "  height: #{parsed_data[:height].inspect}"
    puts "  diameter: #{parsed_data[:diameter].inspect}"
    
    if partial_tire_size && brand_blank && model_blank
      puts "❌ LLM НЕ нужен: найдены частичные размеры шин"
    else
      puts "✅ LLM нужен: brand=#{parsed_data[:brand].inspect}, model=#{parsed_data[:model].inspect}"
    end
  end
else
  puts "❌ Условие (brand.blank? || model.blank?) = false"
  
  # Проверяем сложные паттерны
  puts "Проверяем сложные паттерны..."
  
  complex_patterns = [
    query.match?(/какие|посоветуйте|подойдет|нужны|помогите|скажите|подскажите/i), # Вопросительная форма
    query.match?(/поменял|купил|заменил|установил|ищу|хочу/i), # Контекстные слова
    query.split.length > 8,                     # Очень сложный запрос
    query.match?(/не знаю|не уверен|не помню/i) # Неопределенность
  ]
  
  puts "  Вопросительная форма: #{complex_patterns[0]}"
  puts "  Контекстные слова: #{complex_patterns[1]}"
  puts "  Длинный запрос (>8 слов): #{complex_patterns[2]} (слов: #{query.split.length})"
  puts "  Неопределенность: #{complex_patterns[3]}"
  
  if complex_patterns.any?
    puts "✅ LLM нужен: сложный запрос с паттернами"
  else
    puts "❌ LLM НЕ нужен: простой запрос с найденными brand и model"
  end
end

puts
puts "🔧 Проверяем OpenaiService.available?..."
available = OpenaiService.available?
puts "OpenaiService.available? = #{available}"

puts
puts "✅ Отладка завершена"