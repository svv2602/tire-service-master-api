#!/usr/bin/env ruby

puts '📱 ТЕСТИРОВАНИЕ TELEGRAM УВЕДОМЛЕНИЙ О СЕРВИСНЫХ ТОЧКАХ'
puts '======================================================'

# Получаем первую сервисную точку
service_point = ServicePoint.first
if service_point
  puts "✅ Сервисная точка: #{service_point.name}"
  
  # Получаем настройки Telegram
  settings = TelegramSetting.current
  if settings.enabled? && settings.admin_chat_id.present?
    puts "✅ Telegram настроен, Chat ID: #{settings.admin_chat_id}"
    
    # Создаем сообщения для всех типов уведомлений
    messages = {
      'Создание' => %{
✅ <b>Нова сервісна точка створена!</b>

📋 <b>Деталі сервісної точки:</b>
• Назва: #{service_point.name}
• Адреса: #{service_point.address}
• Місто: #{service_point.city&.name}

🌐 <b>Контакти:</b>
📞 #{service_point.contact_phone}

Дякуємо за додавання сервісної точки! 🙏
      }.strip,
      
      'Изменение' => %{
🔄 <b>Сервісна точка оновлена</b>

📋 <b>Оновлені деталі:</b>
• Назва: #{service_point.name}
• Адреса: #{service_point.address}
• Місто: #{service_point.city&.name}

🌐 <b>Контакти:</b>
📞 #{service_point.contact_phone}

Дякуємо за оновлення сервісної точки! 🙏
      }.strip,
      
      'Изменение статуса' => %{
⚙️ <b>Статус сервісної точки змінено</b>

🏢 <b>Деталі:</b>
• Назва: #{service_point.name}
• Статус: #{service_point.work_status}
• Активна: #{service_point.is_active? ? 'Так' : 'Ні'}

🌐 <b>Контакти:</b>
📞 #{service_point.contact_phone}

Дякуємо за зміну статусу сервісної точки! 🙏
      }.strip
    }
    
    # Отправляем все сообщения
    telegram_service = TelegramService.new
    messages.each do |type, message|
      puts "\n📱 Отправляем: #{type}"
      response = telegram_service.send_message(settings.admin_chat_id, message)
      if response[:ok]
        puts "   ✅ Отправлено (ID: #{response[:result][:message_id]})"
      else
        puts "   ❌ Ошибка: #{response[:description]}"
      end
      sleep(1)
    end
    
  else
    puts '❌ Telegram не настроен'
  end
else
  puts '❌ Нет сервисных точек'
end

puts "\n🎯 ТЕСТИРОВАНИЕ ЗАВЕРШЕНО!"
puts "Проверьте Telegram - должны прийти 3 уведомления о сервисных точках" 