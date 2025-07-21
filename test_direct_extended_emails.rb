#!/usr/bin/env ruby

puts "🎯 ПРЯМАЯ ОТПРАВКА РАСШИРЕННЫХ УВЕДОМЛЕНИЙ"
puts "=========================================="
puts "📧 Отправляем на: svv@invelta.com.ua"

# Находим бронирование для тестов
booking = Booking.first
unless booking
  puts "❌ Нет бронирований для тестирования"
  exit 1
end

puts "📋 Используем бронирование ##{booking.id}"
puts "👤 Клиент: #{booking.service_recipient_first_name} #{booking.service_recipient_last_name}"

# Устанавливаем тестовый email
original_email = booking.service_recipient_email
booking.update_column(:service_recipient_email, 'svv@invelta.com.ua')

begin
  # Создаем экземпляр mailer
  mailer = EmailTemplateMailer.new
  
  puts "\n" + "="*50
  
  # 1. Тест booking_time_changed
  puts "1️⃣ ОТПРАВКА УВЕДОМЛЕНИЯ ОБ ИЗМЕНЕНИИ ВРЕМЕНИ:"
  begin
    # Получаем переменные для бронирования
    variables = mailer.send(:build_booking_variables, booking)
    
    # Отправляем через send_by_template
    mail = mailer.send_by_template('booking_time_changed', 'svv@invelta.com.ua', variables)
    
    if mail
      mail.deliver!
      puts "   ✅ booking_time_changed отправлено!"
      puts "   📬 Тема: #{mail.subject}"
    else
      puts "   ❌ Не удалось создать письмо"
    end
    
  rescue => e
    puts "   ❌ Ошибка: #{e.message}"
  end
  
  sleep 1
  
  # 2. Тест booking_location_changed
  puts "\n2️⃣ ОТПРАВКА УВЕДОМЛЕНИЯ ОБ ИЗМЕНЕНИИ СЕРВИСНОЙ ТОЧКИ:"
  begin
    variables = mailer.send(:build_booking_variables, booking)
    mail = mailer.send_by_template('booking_location_changed', 'svv@invelta.com.ua', variables)
    
    if mail
      mail.deliver!
      puts "   ✅ booking_location_changed отправлено!"
      puts "   📬 Тема: #{mail.subject}"
    else
      puts "   ❌ Не удалось создать письмо"
    end
    
  rescue => e
    puts "   ❌ Ошибка: #{e.message}"
  end
  
  sleep 1
  
  # 3. Тест booking_client_info_changed
  puts "\n3️⃣ ОТПРАВКА УВЕДОМЛЕНИЯ ОБ ИЗМЕНЕНИИ ДАННЫХ КЛИЕНТА:"
  begin
    variables = mailer.send(:build_booking_variables, booking)
    mail = mailer.send_by_template('booking_client_info_changed', 'svv@invelta.com.ua', variables)
    
    if mail
      mail.deliver!
      puts "   ✅ booking_client_info_changed отправлено!"
      puts "   📬 Тема: #{mail.subject}"
    else
      puts "   ❌ Не удалось создать письмо"
    end
    
  rescue => e
    puts "   ❌ Ошибка: #{e.message}"
  end
  
rescue => e
  puts "❌ Общая ошибка: #{e.message}"
  puts "📝 Backtrace: #{e.backtrace.first(3).join('; ')}"
  
ensure
  # Восстанавливаем исходный email
  if original_email
    booking.update_column(:service_recipient_email, original_email)
    puts "\n🔄 Email восстановлен на: #{original_email}"
  end
end

puts "\n" + "="*50
puts "🎯 ИТОГОВЫЙ ОТЧЕТ:"
puts "📧 Письма отправлены на: svv@invelta.com.ua"
puts "📋 Типы отправленных уведомлений:"
puts "   ✉️ Изменение времени бронирования"
puts "   ✉️ Изменение сервисной точки"
puts "   ✉️ Изменение данных клиента"
puts ""
puts "🎉 ТЕСТИРОВАНИЕ ЗАВЕРШЕНО!"
puts "📬 Проверьте почтовый ящик: svv@invelta.com.ua"
puts "💡 Ожидайте 3 письма с украинскими темами" 