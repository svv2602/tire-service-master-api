#!/usr/bin/env ruby
# Тест для проверки доступности OpenAI сервиса

# Добавляем путь к Rails приложению
require_relative '../../config/environment'

puts "🔍 Проверяем доступность OpenAI сервиса..."
puts

# Проверяем OpenaiService.available?
available = OpenaiService.available?
puts "OpenaiService.available? = #{available}"
puts

# Проверяем OpenaiService.configured?
configured = OpenaiService.configured?
puts "OpenaiService.configured? = #{configured}"
puts

# Создаем экземпляр сервиса для детальной проверки
service = OpenaiService.new
puts "Создан экземпляр OpenaiService"

# Проверяем настройки через приватные методы
begin
  api_key = service.send(:openai_api_key)
  puts "OpenAI API Key: #{api_key.present? ? '[УСТАНОВЛЕН]' : '[НЕ УСТАНОВЛЕН]'}"
  puts "Длина ключа: #{api_key.to_s.length} символов"
  
  llm_enabled = service.send(:llm_enabled?)
  puts "LLM включен: #{llm_enabled}"
  
  client = service.instance_variable_get(:@client)
  puts "OpenAI Client: #{client.present? ? '[ИНИЦИАЛИЗИРОВАН]' : '[НЕ ИНИЦИАЛИЗИРОВАН]'}"
  
rescue => e
  puts "❌ Ошибка при проверке настроек: #{e.message}"
end

puts
puts "🧪 Тестируем соединение с OpenAI..."

# Тестируем соединение
test_result = service.test_connection
puts "Результат теста соединения:"
puts "  Успех: #{test_result[:success]}"
puts "  Сообщение: #{test_result[:message]}"

puts
puts "📊 Проверяем системные настройки..."

# Проверяем настройки из БД
begin
  if defined?(SystemSetting)
    openai_key_setting = SystemSetting.find_by(key: 'openai_api_key')
    llm_enable_setting = SystemSetting.find_by(key: 'tire_search_enable_llm')
    
    puts "Настройка 'openai_api_key':"
    if openai_key_setting
      puts "  Значение: #{openai_key_setting.value.present? ? '[УСТАНОВЛЕНО]' : '[ПУСТО]'}"
      puts "  Длина: #{openai_key_setting.value.to_s.length} символов"
    else
      puts "  НЕ НАЙДЕНО в БД"
    end
    
    puts "Настройка 'tire_search_enable_llm':"
    if llm_enable_setting
      puts "  Значение: #{llm_enable_setting.value}"
      puts "  Тип: #{llm_enable_setting.typed_value.class}"
    else
      puts "  НЕ НАЙДЕНО в БД"
    end
  else
    puts "❌ Модель SystemSetting не найдена"
  end
rescue => e
  puts "❌ Ошибка при проверке БД: #{e.message}"
end

puts
puts "✅ Проверка завершена"