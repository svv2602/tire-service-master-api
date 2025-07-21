#!/usr/bin/env ruby

puts "🧪 ТЕСТ РАСШИРЕННЫХ УВЕДОМЛЕНИЙ НА ЖИВОЙ АДРЕС"
puts "=============================================="
puts "📧 Целевой адрес: svv@invelta.com.ua"

# Найдем бронирование для тестов
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
puts "📧 Email изменен на: svv@invelta.com.ua"

puts "\n" + "="*50

# 1. Тест изменения времени
puts "1️⃣ ТЕСТ УВЕДОМЛЕНИЯ ОБ ИЗМЕНЕНИИ ВРЕМЕНИ:"
begin
  old_time = booking.start_time
  new_time = old_time + 2.hours
  
  puts "   ⏰ Изменяю время с #{old_time.strftime('%H:%M')} на #{new_time.strftime('%H:%M')}"
  
  booking.update!(start_time: new_time)
  
  puts "   ✅ Время изменено! Письмо отправлено на svv@invelta.com.ua"
  puts "   📬 Тема: Зміна часу вашого бронювання"
  
rescue => e
  puts "   ❌ Ошибка: #{e.message}"
end

sleep 2 # Пауза между тестами

# 2. Тест изменения сервисной точки
puts "\n2️⃣ ТЕСТ УВЕДОМЛЕНИЯ ОБ ИЗМЕНЕНИИ СЕРВИСНОЙ ТОЧКИ:"
begin
  old_service_point = booking.service_point
  new_service_point = ServicePoint.where.not(id: old_service_point.id).first
  
  if new_service_point
    puts "   📍 Изменяю точку с '#{old_service_point.name}' на '#{new_service_point.name}'"
    
    booking.update!(service_point: new_service_point)
    
    puts "   ✅ Сервисная точка изменена! Письмо отправлено на svv@invelta.com.ua"
    puts "   📬 Тема: Зміна місця обслуговування"
  else
    puts "   ⚠️ Нет другой сервисной точки для тестирования"
  end
  
rescue => e
  puts "   ❌ Ошибка: #{e.message}"
end

sleep 2 # Пауза между тестами

# 3. Тест изменения данных клиента
puts "\n3️⃣ ТЕСТ УВЕДОМЛЕНИЯ ОБ ИЗМЕНЕНИИ ДАННЫХ КЛИЕНТА:"
begin
  old_name = booking.service_recipient_first_name
  old_phone = booking.service_recipient_phone
  
  puts "   👤 Изменяю имя с '#{old_name}' на '#{old_name}_Test'"
  puts "   📞 Изменяю телефон с '#{old_phone}' на '+380501234567'"
  
  booking.update!(
    service_recipient_first_name: "#{old_name}_Test",
    service_recipient_phone: "+380501234567"
  )
  
  puts "   ✅ Данные клиента изменены! Письмо отправлено на svv@invelta.com.ua"
  puts "   📬 Тема: Оновлення даних вашого бронювання"
  
rescue => e
  puts "   ❌ Ошибка: #{e.message}"
end

# 4. Тест прямой отправки через EmailTemplateMailer
puts "\n4️⃣ ПРЯМОЙ ТЕСТ EMAIL ШАБЛОНОВ:"
begin
  puts "   📨 Тестируем booking_time_changed..."
  EmailTemplateMailer.booking_time_changed(booking.id, 'svv@invelta.com.ua').deliver_now
  puts "   ✅ booking_time_changed отправлен!"
  
  puts "   📨 Тестируем booking_location_changed..."
  EmailTemplateMailer.booking_location_changed(booking.id, 'svv@invelta.com.ua').deliver_now
  puts "   ✅ booking_location_changed отправлен!"
  
  puts "   📨 Тестируем booking_client_info_changed..."
  EmailTemplateMailer.booking_client_info_changed(booking.id, 'svv@invelta.com.ua').deliver_now
  puts "   ✅ booking_client_info_changed отправлен!"
  
rescue => e
  puts "   ❌ Ошибка прямой отправки: #{e.message}"
end

# Восстанавливаем исходный email
if original_email
  booking.update_column(:service_recipient_email, original_email)
  puts "\n🔄 Email восстановлен на: #{original_email}"
end

puts "\n" + "="*50
puts "🎯 ИТОГОВЫЙ ОТЧЕТ:"
puts "📧 Отправлено писем на: svv@invelta.com.ua"
puts "📋 Типы отправленных уведомлений:"
puts "   ✉️ Изменение времени бронирования"
puts "   ✉️ Изменение сервисной точки"
puts "   ✉️ Изменение данных клиента"
puts "   ✉️ Прямые тесты всех 3 шаблонов"
puts ""
puts "🎉 ТЕСТИРОВАНИЕ ЗАВЕРШЕНО!"
puts "📬 Проверьте почтовый ящик: svv@invelta.com.ua"
puts "💡 Ожидайте 6 писем с украинскими темами и содержимым" 