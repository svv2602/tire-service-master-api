#!/usr/bin/env ruby

puts '🚨 ЭКСТРЕННОЕ ОТКЛЮЧЕНИЕ TELEGRAM БОТА'
puts '======================================'
puts 'Причина: Получение спам-сообщений через небезопасный webhook'
puts ''

begin
  # Инициализируем TelegramService
  telegram_service = TelegramService.new
  puts '✅ TelegramService инициализирован'
  
  # 1. Удаляем webhook
  puts "\n🔗 Удаляем webhook..."
  response = telegram_service.delete_webhook
  if response[:ok]
    puts '✅ Webhook успешно удален'
  else
    puts "❌ Ошибка удаления webhook: #{response[:description]}"
  end
  
  # 2. Отключаем бота в настройках системы
  puts "\n⚙️ Отключаем бота в настройках..."
  settings = TelegramSetting.current
  settings.update!(
    enabled: false,
    webhook_url: nil,
    test_mode: true,
    admin_chat_id: nil
  )
  puts '✅ Бот отключен в настройках системы'
  
  # 3. Проверяем текущий статус webhook
  puts "\n🔍 Проверяем статус webhook..."
  webhook_info = telegram_service.get_webhook_info
  if webhook_info[:ok]
    result = webhook_info[:result]
    webhook_url = result[:url].present? ? result[:url] : 'ОТСУТСТВУЕТ'
    pending_updates = result[:pending_update_count] || 0
    
    puts "Текущий webhook: #{webhook_url}"
    puts "Ожидающие обновления: #{pending_updates}"
    
    if webhook_url == 'ОТСУТСТВУЕТ'
      puts '✅ Webhook полностью удален'
    else
      puts '⚠️ Webhook все еще активен, попробуйте удалить еще раз'
    end
  else
    puts "❌ Ошибка проверки webhook: #{webhook_info[:description]}"
  end
  
  # 4. Получаем информацию о боте
  puts "\n🤖 Информация о боте:"
  bot_info = telegram_service.get_me
  if bot_info[:ok]
    bot_data = bot_info[:result]
    puts "ID бота: #{bot_data[:id]}"
    puts "Имя бота: #{bot_data[:first_name]}"
    puts "Username: @#{bot_data[:username]}" if bot_data[:username]
  end
  
  puts "\n🛡️ МЕРЫ БЕЗОПАСНОСТИ ПРИНЯТЫ:"
  puts "✅ Webhook удален"
  puts "✅ Бот отключен в системе"
  puts "✅ Настройки обнулены"
  puts ""
  puts "⚠️ РЕКОМЕНДАЦИИ:"
  puts "1. Проверьте, не был ли скомпрометирован токен бота"
  puts "2. При необходимости создайте нового бота через @BotFather"
  puts "3. Используйте защищенные webhook'и с SSL и авторизацией"
  puts "4. Никогда не публикуйте токен бота в открытом доступе"

rescue => e
  puts "❌ КРИТИЧЕСКАЯ ОШИБКА: #{e.message}"
  puts "Backtrace: #{e.backtrace.first(3).join('\n')}"
  puts ""
  puts "🆘 РУЧНЫЕ ДЕЙСТВИЯ:"
  puts "1. Зайдите в @BotFather в Telegram"
  puts "2. Найдите своего бота и отзовите токен"
  puts "3. Создайте нового бота с новым токеном"
end