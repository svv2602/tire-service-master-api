#!/usr/bin/env ruby

puts '📱 ТЕСТИРОВАНИЕ ОТПРАВКИ TELEGRAM СООБЩЕНИЙ'
puts '==========================================='

# Получаем настройки
settings = TelegramSetting.current
puts "📊 Статус системы: #{settings.status_text}"

# Инициализируем сервис
telegram_service = TelegramService.new
puts "✅ TelegramService готов"

puts "\n🔍 ПОЛУЧЕНИЕ ОБНОВЛЕНИЙ ДЛЯ ПОИСКА CHAT ID"
puts "=========================================="

# Получаем последние обновления
updates = telegram_service.get_updates
if updates[:ok] && updates[:result].any?
  puts "📬 Найдено #{updates[:result].length} обновлений:"
  
  updates[:result].each_with_index do |update, index|
    puts "\n📨 Обновление #{index + 1}:"
    
    if update[:message]
      message = update[:message]
      chat = message[:chat]
      from = message[:from]
      
      puts "   💬 Сообщение: #{message[:text]}"
      puts "   👤 От: #{from[:first_name]} #{from[:last_name]} (@#{from[:username]})"
      puts "   🆔 Chat ID: #{chat[:id]} ⭐ ВАЖНО ДЛЯ НАСТРОЙКИ!"
      puts "   📅 Дата: #{Time.at(message[:date]).strftime('%d.%m.%Y %H:%M')}"
      
      # Автоматически установим первый найденный chat_id как admin_chat_id
      if index == 0 && settings.admin_chat_id.blank?
        settings.update!(admin_chat_id: chat[:id].to_s)
        puts "   ✅ Автоматически установлен как Admin Chat ID"
      end
    end
  end
else
  puts "📭 Обновлений не найдено"
  puts "💡 Напишите боту @tire_service_ua_bot любое сообщение (например: /start)"
end

puts "\n🧪 ОТПРАВКА ТЕСТОВОГО СООБЩЕНИЯ"
puts "==============================="

# Проверяем есть ли admin_chat_id
admin_chat_id = settings.reload.admin_chat_id
if admin_chat_id.present?
  puts "🎯 Отправляем тестовое сообщение в Chat ID: #{admin_chat_id}"
  
  test_message = "🧪 <b>Тестовое сообщение системы уведомлений</b>\n\n" \
                 "✅ Telegram бот работает корректно!\n" \
                 "📅 Время: #{Time.current.strftime('%d.%m.%Y %H:%M:%S')}\n" \
                 "🤖 Бот: @tire_service_ua_bot\n\n" \
                 "🎯 <i>Система готова к отправке уведомлений о бронированиях!</i>"
  
  response = telegram_service.send_message(admin_chat_id, test_message)
  
  if response[:ok]
    puts "✅ СООБЩЕНИЕ ОТПРАВЛЕНО УСПЕШНО!"
    puts "   📨 Message ID: #{response[:result][:message_id]}"
    puts "   📅 Дата: #{Time.at(response[:result][:date]).strftime('%d.%m.%Y %H:%M:%S')}"
  else
    puts "❌ ОШИБКА ОТПРАВКИ:"
    puts "   Описание: #{response[:description]}"
    puts "   Код ошибки: #{response[:error_code]}" if response[:error_code]
  end
else
  puts "⚠️ Admin Chat ID не установлен"
  puts "💡 Сначала напишите боту @tire_service_ua_bot сообщение"
end

puts "\n📊 ТЕКУЩИЕ НАСТРОЙКИ:"
puts "===================="
settings.reload
puts "🔧 Bot Token: #{settings.bot_token[0..15]}..."
puts "🆔 Admin Chat ID: #{settings.admin_chat_id || 'НЕ УСТАНОВЛЕН'}"
puts "✅ Включен: #{settings.enabled?}"
puts "🧪 Тестовый режим: #{settings.test_mode?}"
puts "📊 Статус: #{settings.status_text}"

puts "\n🎯 ГОТОВО К ТЕСТИРОВАНИЮ УВЕДОМЛЕНИЙ О БРОНИРОВАНИЯХ!" 