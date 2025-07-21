#!/usr/bin/env ruby

puts "🧪 ТЕСТИРОВАНИЕ АВТОМАТИЧЕСКИХ EMAIL УВЕДОМЛЕНИЙ"
puts "=" * 60

# 1. Проверяем существующие бронирования
puts "1️⃣ АНАЛИЗ СУЩЕСТВУЮЩИХ БРОНИРОВАНИЙ:"
bookings = Booking.includes(:service_point, :client).limit(3)
if bookings.any?
  bookings.each do |booking|
    puts "   📋 Бронирование ##{booking.id}:"
    puts "      Клиент: #{booking.service_recipient_first_name} #{booking.service_recipient_last_name}"
    puts "      Email: #{booking.service_recipient_email || booking.client&.email || 'НЕ УКАЗАН'}"
    puts "      Статус: #{booking.status}"
    puts "      Дата: #{booking.booking_date}"
    puts ""
  end
else
  puts "   ❌ Нет бронирований для тестирования"
end

puts ""

# 2. Тестируем создание нового бронирования
puts "2️⃣ ТЕСТ СОЗДАНИЯ НОВОГО БРОНИРОВАНИЯ:"
begin
  # Находим данные для создания тестового бронирования
  service_point = ServicePoint.active.first
  car_type = CarType.active.first
  client = Client.first

  if service_point && car_type && client
    puts "   📍 Сервисная точка: #{service_point.name}"
    puts "   🚗 Тип авто: #{car_type.name}"
    puts "   👤 Клиент: #{client.user.first_name} #{client.user.last_name}"
    
    # Создаем тестовое бронирование (отключаем валидацию времени для теста)
    test_booking = Booking.new(
      service_point: service_point,
      car_type: car_type,
      client: client,
      booking_date: Date.current + 1.day,
      start_time: Time.current.change(hour: 14, min: 0),
      end_time: Time.current.change(hour: 15, min: 0),
      service_recipient_first_name: 'Тестовый',
      service_recipient_last_name: 'Клиент',
      service_recipient_phone: '+38067123456',
      service_recipient_email: 'svv@invelta.com.ua', # Тестовый email
      car_brand: 'Toyota',
      car_model: 'Camry',
      license_plate: 'TE1234ST',
      skip_availability_check: true # Пропускаем проверку доступности для теста
    )

    puts "   💾 Сохраняем бронирование..."
    if test_booking.save
      puts "   ✅ Бронирование ##{test_booking.id} создано успешно!"
      puts "   📧 Автоматическое уведомление должно быть отправлено на svv@invelta.com.ua"
      
      # Сохраняем ID для дальнейших тестов
      @test_booking_id = test_booking.id
    else
      puts "   ❌ Ошибка создания: #{test_booking.errors.full_messages.join(', ')}"
    end
  else
    puts "   ⚠️ Недостаточно данных для создания тестового бронирования"
  end
rescue => e
  puts "   ❌ Исключение при создании: #{e.message}"
end

puts ""

# 3. Тестируем изменение статуса
puts "3️⃣ ТЕСТ ИЗМЕНЕНИЯ СТАТУСА БРОНИРОВАНИЯ:"
test_booking_for_status = @test_booking_id ? Booking.find(@test_booking_id) : Booking.first

if test_booking_for_status
  begin
    puts "   📋 Используем бронирование ##{test_booking_for_status.id}"
    puts "   📧 Email: #{test_booking_for_status.service_recipient_email || test_booking_for_status.client&.email}"
    
    # Устанавливаем тестовый email если его нет
    if test_booking_for_status.service_recipient_email.blank? && test_booking_for_status.client&.email.blank?
      test_booking_for_status.update_column(:service_recipient_email, 'svv@invelta.com.ua')
      puts "   📧 Установлен тестовый email: svv@invelta.com.ua"
    end
    
    puts "   📋 Тестируем смену статуса на 'confirmed'..."
    test_booking_for_status.update!(status: 'confirmed')
    puts "   ✅ Статус изменен! Должно быть отправлено уведомление о подтверждении"
    
    puts "   📋 Тестируем смену статуса на 'completed'..."
    test_booking_for_status.update!(status: 'completed')
    puts "   ✅ Статус изменен! Должны быть отправлены уведомления о завершении и запрос отзыва"
    
  rescue => e
    puts "   ❌ Ошибка изменения статуса: #{e.message}"
  end
else
  puts "   ⚠️ Нет бронирований для тестирования изменения статуса"
end

puts ""

# 4. Тестируем Job'ы напрямую
puts "4️⃣ ТЕСТ BACKGROUND JOBS:"

# Тестируем BookingNotificationJob напрямую
test_booking_id = @test_booking_id || Booking.first&.id
if test_booking_id
  puts "   📧 Тестируем BookingNotificationJob с бронированием ##{test_booking_id}..."
  
  # Устанавливаем тестовый email для бронирования
  booking = Booking.find(test_booking_id)
  if booking.service_recipient_email.blank? && booking.client&.email.blank?
    booking.update_column(:service_recipient_email, 'svv@invelta.com.ua')
    puts "   📧 Установлен тестовый email для бронирования"
  end
  
  begin
    # Тестируем напрямую через EmailTemplateMailer для мгновенной отправки
    EmailTemplateMailer.booking_confirmation(test_booking_id, 'svv@invelta.com.ua').deliver_now
    puts "   ✅ EmailTemplateMailer.booking_confirmation выполнен успешно!"
    
    # Также тестируем сам Job
    BookingNotificationJob.perform_now(test_booking_id, 'booking_created')
    puts "   ✅ BookingNotificationJob выполнен успешно!"
  rescue => e
    puts "   ❌ Ошибка: #{e.message}"
    puts "   🔍 Детали: #{e.backtrace.first(3).join('; ')}"
  end
else
  puts "   ⚠️ Нет ID для тестирования BookingNotificationJob"
end

# Тестируем BookingRemindersJob
puts "   ⏰ Тестируем BookingRemindersJob..."
begin
  BookingRemindersJob.perform_now
  puts "   ✅ BookingRemindersJob выполнен успешно!"
rescue => e
  puts "   ❌ Ошибка BookingRemindersJob: #{e.message}"
end

# Тестируем DailyRemindersJob
puts "   📅 Тестируем DailyRemindersJob..."
begin
  DailyRemindersJob.perform_now
  puts "   ✅ DailyRemindersJob выполнен успешно!"
rescue => e
  puts "   ❌ Ошибка DailyRemindersJob: #{e.message}"
end

puts ""

# 5. Проверяем логи
puts "5️⃣ ПРОВЕРКА ЛОГОВ ОТПРАВКИ:"
puts "   📝 Последние записи в логах Rails:"
begin
  log_file = Rails.root.join('log', 'development.log')
  if File.exist?(log_file)
    last_logs = `tail -20 #{log_file} | grep -E "(BookingNotificationJob|EmailTemplateMailer|✅|❌)"`
    if last_logs.present?
      puts last_logs
    else
      puts "   ⚠️ Нет релевантных записей в логах"
    end
  else
    puts "   ⚠️ Файл логов не найден"
  end
rescue => e
  puts "   ❌ Ошибка чтения логов: #{e.message}"
end

puts ""

# 6. Итоговый отчет
puts "🎯 ИТОГОВЫЙ ОТЧЕТ:"
puts "   📧 Все email должны быть отправлены на: svv@invelta.com.ua"
puts "   🔍 Проверьте почтовый ящик на наличие уведомлений"
puts "   📋 Типы отправленных уведомлений:"
puts "      - Подтверждение создания бронирования"
puts "      - Подтверждение бронирования" 
puts "      - Уведомление о завершении обслуживания"
puts "      - Запрос на отзыв"
puts "      - Напоминания (если есть подходящие записи)"
puts ""
puts "🎉 ТЕСТИРОВАНИЕ ЗАВЕРШЕНО!"
puts "📬 Проверьте email: svv@invelta.com.ua" 