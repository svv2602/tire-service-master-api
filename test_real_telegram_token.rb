#!/usr/bin/env ruby

puts '🤖 НАСТРОЙКА РЕАЛЬНОГО TELEGRAM ТОКЕНА'
puts '===================================='

# Устанавливаем реальный токен
token = '8128980955:AAFO43qP_B_nG61gYktAJv3EESR7d8kxsEs'

# Обновляем настройки
settings = TelegramSetting.current
settings.update!(
  bot_token: token,
  enabled: true,
  test_mode: true
)

puts "✅ Токен установлен: #{token[0..15]}..."
puts "📊 Статус: #{settings.reload.status_text}"
puts "🔧 Конфигурация валидна: #{settings.valid_configuration?}"

puts "\n🔍 ТЕСТИРОВАНИЕ ПОДКЛЮЧЕНИЯ К TELEGRAM API"
puts "=========================================="

begin
  # Инициализируем TelegramService
  telegram_service = TelegramService.new
  puts "✅ TelegramService инициализирован"
  
  # Тестируем подключение к боту
  puts "\n📡 Получаем информацию о боте..."
  bot_info = telegram_service.get_me
  
  if bot_info[:ok]
    bot_data = bot_info[:result]
    puts "✅ ПОДКЛЮЧЕНИЕ К БОТУ УСПЕШНО!"
    puts "   🤖 ID: #{bot_data[:id]}"
    puts "   📛 Имя: #{bot_data[:first_name]}"
    puts "   👤 Username: @#{bot_data[:username]}" if bot_data[:username]
    puts "   👥 Может присоединяться к группам: #{bot_data[:can_join_groups]}"
    puts "   📖 Может читать все сообщения группы: #{bot_data[:can_read_all_group_messages]}"
    puts "   🔍 Поддерживает inline запросы: #{bot_data[:supports_inline_queries]}"
  else
    puts "❌ ОШИБКА ПОДКЛЮЧЕНИЯ К БОТУ:"
    puts "   Описание: #{bot_info[:description]}"
    puts "   Код ошибки: #{bot_info[:error_code]}" if bot_info[:error_code]
  end
  
  puts "\n🔗 ИНФОРМАЦИЯ О WEBHOOK"
  puts "======================="
  
  webhook_info = telegram_service.get_webhook_info
  if webhook_info[:ok]
    webhook_data = webhook_info[:result]
    puts "📋 URL: #{webhook_data[:url].presence || 'НЕ УСТАНОВЛЕН'}"
    puts "📊 Ожидающих обновлений: #{webhook_data[:pending_update_count]}"
    puts "📅 Последняя ошибка: #{webhook_data[:last_error_date]}" if webhook_data[:last_error_date]
    puts "💬 Сообщение об ошибке: #{webhook_data[:last_error_message]}" if webhook_data[:last_error_message]
  else
    puts "❌ Ошибка получения информации о webhook: #{webhook_info[:description]}"
  end
  
rescue => e
  puts "❌ ИСКЛЮЧЕНИЕ ПРИ ТЕСТИРОВАНИИ:"
  puts "   #{e.message}"
  puts "   #{e.backtrace.first(3).join('\n   ')}"
end

puts "\n💡 СЛЕДУЮЩИЕ ШАГИ:"
puts "1. Найдите ваш Chat ID (напишите боту /start)"
puts "2. Обновите admin_chat_id в настройках"
puts "3. Протестируйте отправку сообщения"
puts "4. Настройте webhook для продакшн использования"

puts "\n🎯 ГОТОВО К ТЕСТИРОВАНИЮ УВЕДОМЛЕНИЙ!" 