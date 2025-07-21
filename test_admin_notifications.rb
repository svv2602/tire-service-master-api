#!/usr/bin/env ruby

puts "🔔 ТЕСТ АДМИНСКИХ УВЕДОМЛЕНИЙ"
puts "============================="

# Устанавливаем тестовый email администратора
ENV['ADMIN_NOTIFICATION_EMAILS'] = 'svv@invelta.com.ua'

booking = Booking.first
unless booking
  puts "❌ Нет бронирований для тестирования"
  exit 1
end

puts "📋 Используем бронирование ##{booking.id}"
puts "👤 Клиент: #{booking.service_recipient_first_name} #{booking.service_recipient_last_name}"
puts "📧 Админские уведомления будут отправлены на: #{ENV['ADMIN_NOTIFICATION_EMAILS']}"

puts "\n" + "="*50

# 1. Тест уведомления о новом бронировании
puts "1️⃣ ТЕСТ АДМИНСКОГО УВЕДОМЛЕНИЯ О НОВОМ БРОНИРОВАНИИ:"
begin
  puts "   📧 Отправляем admin_new_booking..."
  BookingNotificationJob.perform_now(booking.id, 'admin_new_booking', 'svv@invelta.com.ua')
  puts "   ✅ Уведомление отправлено!"
  
rescue => e
  puts "   ❌ Ошибка: #{e.message}"
end

sleep 2

# 2. Тест уведомления об изменении бронирования
puts "\n2️⃣ ТЕСТ АДМИНСКОГО УВЕДОМЛЕНИЯ ОБ ИЗМЕНЕНИИ:"
begin
  puts "   📧 Отправляем admin_booking_changed..."
  BookingNotificationJob.perform_now(booking.id, 'admin_booking_changed', 'svv@invelta.com.ua')
  puts "   ✅ Уведомление отправлено!"
  
rescue => e
  puts "   ❌ Ошибка: #{e.message}"
end

sleep 2

# 3. Тест уведомления об отмене бронирования
puts "\n3️⃣ ТЕСТ АДМИНСКОГО УВЕДОМЛЕНИЯ ОБ ОТМЕНЕ:"
begin
  puts "   📧 Отправляем admin_booking_cancelled..."
  BookingNotificationJob.perform_now(booking.id, 'admin_booking_cancelled', 'svv@invelta.com.ua')
  puts "   ✅ Уведомление отправлено!"
  
rescue => e
  puts "   ❌ Ошибка: #{e.message}"
end

# 4. Тест автоматических уведомлений при создании нового бронирования
puts "\n4️⃣ ТЕСТ АВТОМАТИЧЕСКИХ УВЕДОМЛЕНИЙ ПРИ СОЗДАНИИ:"
begin
  puts "   🔄 Создаем тестовое бронирование..."
  
  test_booking = Booking.new(
    service_point_id: booking.service_point_id,
    service_category_id: booking.service_category_id,
    booking_date: Date.tomorrow,
    start_time: Time.parse('10:00'),
    service_recipient_first_name: 'Тестовый',
    service_recipient_last_name: 'Клиент',
    service_recipient_phone: '+380501234567',
    service_recipient_email: 'test@example.com',
    license_plate: 'TEST123',
    car_brand: 'Toyota',
    car_model: 'Camry',
    status: 'pending',
    skip_availability_check: true
  )
  
  if test_booking.save
    puts "   ✅ Тестовое бронирование создано! ID: #{test_booking.id}"
    puts "   📧 Админское уведомление должно быть отправлено автоматически"
    
    # Удаляем тестовое бронирование
    test_booking.destroy
    puts "   🗑️ Тестовое бронирование удалено"
  else
    puts "   ❌ Не удалось создать тестовое бронирование: #{test_booking.errors.full_messages.join(', ')}"
  end
  
rescue => e
  puts "   ❌ Ошибка: #{e.message}"
end

puts "\n" + "="*50
puts "🎯 ИТОГОВЫЙ ОТЧЕТ:"
puts "📧 Отправлено админских уведомлений на: svv@invelta.com.ua"
puts "📋 Типы отправленных уведомлений:"
puts "   ✉️ Новое бронирование (админ)"
puts "   ✉️ Изменение бронирования (админ)"
puts "   ✉️ Отмена бронирования (админ)"
puts "   ✉️ Автоматическое уведомление при создании"
puts ""
puts "🎉 ТЕСТИРОВАНИЕ АДМИНСКИХ УВЕДОМЛЕНИЙ ЗАВЕРШЕНО!"
puts "📬 Проверьте почтовый ящик: svv@invelta.com.ua"
puts "💡 Ожидайте 4 письма с админскими уведомлениями" 