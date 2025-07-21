#!/usr/bin/env ruby

puts "🧪 ТЕСТИРОВАНИЕ РАСШИРЕННЫХ СОБЫТИЙ БРОНИРОВАНИЙ"
puts "================================================"

# Найдем существующее бронирование для тестов
booking = Booking.first
unless booking
  puts "❌ Нет бронирований для тестирования"
  exit 1
end

puts "📋 Используем бронирование ##{booking.id}"
puts "👤 Клиент: #{booking.service_recipient_first_name} #{booking.service_recipient_last_name}"
puts "📧 Email: #{booking.service_recipient_email || 'svv@invelta.com.ua'}"
puts "📍 Сервисная точка: #{booking.service_point.name}"
puts "📅 Дата: #{booking.booking_date}"
puts "⏰ Время: #{booking.start_time&.strftime('%H:%M')}"

# Устанавливаем тестовый email если его нет
if booking.service_recipient_email.blank?
  booking.update_column(:service_recipient_email, 'svv@invelta.com.ua')
  puts "📧 Установлен тестовый email: svv@invelta.com.ua"
end

puts "\n" + "="*50

# 1. Тест изменения времени
puts "1️⃣ ТЕСТ ИЗМЕНЕНИЯ ВРЕМЕНИ БРОНИРОВАНИЯ:"
begin
  old_time = booking.start_time
  new_time = old_time + 1.hour
  
  puts "   ⏰ Старое время: #{old_time.strftime('%H:%M')}"
  puts "   ⏰ Новое время: #{new_time.strftime('%H:%M')}"
  
  # Отключаем уведомления для первого обновления
  booking.skip_notifications = true
  booking.update!(start_time: new_time)
  
  # Включаем уведомления и делаем еще одно изменение
  booking.skip_notifications = false
  booking.update!(start_time: new_time + 30.minutes)
  
  puts "   ✅ Время изменено! Должно быть отправлено уведомление об изменении времени"
  
rescue => e
  puts "   ❌ Ошибка изменения времени: #{e.message}"
end

# 2. Тест изменения даты
puts "\n2️⃣ ТЕСТ ИЗМЕНЕНИЯ ДАТЫ БРОНИРОВАНИЯ:"
begin
  old_date = booking.booking_date
  new_date = old_date + 1.day
  
  puts "   📅 Старая дата: #{old_date.strftime('%d.%m.%Y')}"
  puts "   📅 Новая дата: #{new_date.strftime('%d.%m.%Y')}"
  
  booking.update!(booking_date: new_date)
  
  puts "   ✅ Дата изменена! Должно быть отправлено уведомление об изменении времени"
  
rescue => e
  puts "   ❌ Ошибка изменения даты: #{e.message}"
end

# 3. Тест изменения сервисной точки
puts "\n3️⃣ ТЕСТ ИЗМЕНЕНИЯ СЕРВИСНОЙ ТОЧКИ:"
begin
  old_service_point = booking.service_point
  new_service_point = ServicePoint.where.not(id: old_service_point.id).first
  
  if new_service_point
    puts "   📍 Старая точка: #{old_service_point.name}"
    puts "   📍 Новая точка: #{new_service_point.name}"
    
    booking.update!(service_point: new_service_point)
    
    puts "   ✅ Сервисная точка изменена! Должно быть отправлено уведомление об изменении локации"
  else
    puts "   ⚠️ Нет другой сервисной точки для тестирования"
  end
  
rescue => e
  puts "   ❌ Ошибка изменения сервисной точки: #{e.message}"
end

# 4. Тест изменения данных клиента
puts "\n4️⃣ ТЕСТ ИЗМЕНЕНИЯ ДАННЫХ КЛИЕНТА:"
begin
  old_name = booking.service_recipient_first_name
  old_phone = booking.service_recipient_phone
  
  puts "   👤 Старое имя: #{old_name}"
  puts "   📞 Старый телефон: #{old_phone}"
  
  booking.update!(
    service_recipient_first_name: "#{old_name}_Updated",
    service_recipient_phone: "+380671234567"
  )
  
  puts "   👤 Новое имя: #{booking.service_recipient_first_name}"
  puts "   📞 Новый телефон: #{booking.service_recipient_phone}"
  puts "   ✅ Данные клиента изменены! Должно быть отправлено уведомление об изменении данных"
  
rescue => e
  puts "   ❌ Ошибка изменения данных клиента: #{e.message}"
end

# 5. Проверка логов
puts "\n5️⃣ ПРОВЕРКА ЛОГОВ ОТПРАВКИ:"
puts "   📝 Последние записи в логах Rails:"
log_entries = `tail -n 10 log/development.log | grep -E "(📅|📍|👤|✅.*уведомление)" | tail -5`
if log_entries.empty?
  puts "   ⚠️ Нет записей о расширенных уведомлениях в логах"
else
  log_entries.split("\n").each { |line| puts "   #{line}" }
end

puts "\n" + "="*50
puts "🎯 ИТОГОВЫЙ ОТЧЕТ:"
puts "📧 Все уведомления должны быть отправлены на: #{booking.service_recipient_email}"
puts "📋 Типы отправленных уведомлений:"
puts "   - Изменение времени/даты бронирования"
puts "   - Изменение сервисной точки (если доступна)"
puts "   - Изменение данных клиента"
puts ""
puts "🎉 ТЕСТИРОВАНИЕ РАСШИРЕННЫХ СОБЫТИЙ ЗАВЕРШЕНО!"
puts "📬 Проверьте email: #{booking.service_recipient_email}" 