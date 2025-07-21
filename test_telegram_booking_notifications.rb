#!/usr/bin/env ruby

puts "📱 ТЕСТ TELEGRAM УВЕДОМЛЕНИЙ О БРОНИРОВАНИЯХ"
puts "==========================================="

# Проверяем наличие Telegram токена
unless ENV['TELEGRAM_BOT_TOKEN']
  puts "❌ TELEGRAM_BOT_TOKEN не установлен"
  puts "💡 Установите переменную окружения для тестирования"
  exit 1
end

# Создаем тестового пользователя с Telegram подпиской
puts "1️⃣ СОЗДАНИЕ ТЕСТОВОГО ПОЛЬЗОВАТЕЛЯ С TELEGRAM"
puts "============================================="

test_user = User.find_or_initialize_by(email: 'telegram_test@example.com')
if test_user.new_record?
  test_user.assign_attributes(
    first_name: 'Telegram',
    last_name: 'Тестер',
    phone: '+380501234567',
    password: 'test123',
    role_id: UserRole.find_by(name: 'client')&.id || 1
  )
  test_user.save!
  puts "✅ Создан тестовый пользователь: #{test_user.email}"
else
  puts "✅ Найден тестовый пользователь: #{test_user.email}"
end

# Создаем Telegram подписку
telegram_subscription = TelegramSubscription.find_or_initialize_by(user: test_user)
if telegram_subscription.new_record?
  telegram_subscription.assign_attributes(
    chat_id: '123456789', # Тестовый chat_id
    username: 'telegram_tester',
    first_name: 'Telegram',
    last_name: 'Тестер',
    is_active: true,
    status: 'active'
  )
  telegram_subscription.save!
  puts "✅ Создана Telegram подписка для chat_id: #{telegram_subscription.chat_id}"
else
  puts "✅ Найдена Telegram подписка для chat_id: #{telegram_subscription.chat_id}"
end

# Создаем тестовое бронирование
puts "\n2️⃣ СОЗДАНИЕ ТЕСТОВОГО БРОНИРОВАНИЯ"
puts "=================================="

# Получаем необходимые данные
service_point = ServicePoint.first
client = Client.first || Client.create!(
  first_name: 'Test',
  last_name: 'Client',
  phone: '+380501234567',
  email: 'test_client@example.com'
)
car_type = CarType.first || CarType.create!(name: 'Легковой автомобиль')

booking = Booking.new(
  client: client,
  service_point: service_point,
  car_type: car_type,
  booking_date: Date.tomorrow,
  start_time: Time.current + 2.hours,
  car_brand: 'Toyota',
  car_model: 'Camry',
  license_plate: 'AA1234BB',
  status: 'pending',
  skip_notifications: false
)

if booking.save
  puts "✅ Создано тестовое бронирование ID: #{booking.id}"
  puts "📋 Детали:"
  puts "   📧 Email: #{booking.service_recipient_email}"
  puts "   📱 Phone: #{booking.service_recipient_phone}"
  puts "   📅 Date: #{booking.booking_date}"
  puts "   ⏰ Time: #{booking.start_time.strftime('%H:%M')}"
else
  puts "❌ Не удалось создать бронирование: #{booking.errors.full_messages.join(', ')}"
  exit 1
end

puts "\n3️⃣ ТЕСТИРОВАНИЕ TELEGRAM УВЕДОМЛЕНИЙ"
puts "===================================="

# Тест 1: Подтверждение бронирования
puts "\n📱 Тест 1: Подтверждение бронирования"
puts "-----------------------------------"
begin
  BookingNotificationJob.perform_now(booking.id, 'telegram_booking_created')
  puts "✅ Уведомление о создании отправлено"
rescue => e
  puts "❌ Ошибка: #{e.message}"
end

sleep 1

# Тест 2: Изменение времени
puts "\n⏰ Тест 2: Изменение времени"
puts "---------------------------"
begin
  # Изменяем время бронирования
  old_time = booking.start_time
  new_time = Time.parse('14:00')
  booking.update_column(:start_time, new_time)

  BookingNotificationJob.perform_now(booking.id, 'telegram_booking_time_changed')
  puts "✅ Уведомление об изменении времени отправлено"
  puts "   Было: #{old_time.strftime('%H:%M')}"
  puts "   Стало: #{new_time.strftime('%H:%M')}"
rescue => e
  puts "❌ Ошибка: #{e.message}"
end

sleep 1

# Тест 3: Изменение места
puts "\n📍 Тест 3: Изменение места"
puts "-------------------------"
begin
  # Находим другую сервисную точку
  new_service_point = ServicePoint.where.not(id: booking.service_point_id).first
  if new_service_point
    booking.update_column(:service_point_id, new_service_point.id)

    BookingNotificationJob.perform_now(booking.id, 'telegram_booking_location_changed')
    puts "✅ Уведомление об изменении места отправлено"
    puts "   Новое место: #{new_service_point.name}"
  else
    puts "⚠️ Не найдена альтернативная сервисная точка для теста"
  end
rescue => e
  puts "❌ Ошибка: #{e.message}"
end

sleep 1

# Тест 4: Отмена бронирования
puts "\n❌ Тест 4: Отмена бронирования"
puts "-----------------------------"
begin
  booking.update_column(:status, 'cancelled')

  BookingNotificationJob.perform_now(booking.id, 'telegram_booking_cancelled')
  puts "✅ Уведомление об отмене отправлено"
rescue => e
  puts "❌ Ошибка: #{e.message}"
end

puts "\n4️⃣ ОЧИСТКА ТЕСТОВЫХ ДАННЫХ"
puts "=========================="

# Удаляем тестовое бронирование
booking.destroy
puts "🗑️ Удалено тестовое бронирование"

# Оставляем пользователя и подписку для будущих тестов
puts "👤 Тестовый пользователь и Telegram подписка оставлены для будущих тестов"

puts "\n🎯 ИТОГОВЫЙ ОТЧЕТ"
puts "================"
puts "📱 Протестированы 4 типа Telegram уведомлений:"
puts "   ✅ Подтверждение бронирования"
puts "   ⏰ Изменение времени"
puts "   📍 Изменение места"
puts "   ❌ Отмена бронирования"
puts ""
puts "📊 Статистика Telegram уведомлений:"
total_notifications = TelegramNotification.count
sent_notifications = TelegramNotification.sent.count
puts "   📧 Всего: #{total_notifications}"
puts "   ✅ Отправлено: #{sent_notifications}"
puts "   📈 Успешность: #{total_notifications > 0 ? (sent_notifications.to_f / total_notifications * 100).round(1) : 0}%"
puts ""
puts "🎉 ТЕСТИРОВАНИЕ TELEGRAM УВЕДОМЛЕНИЙ ЗАВЕРШЕНО!"
puts "💡 Проверьте Telegram чат с chat_id: #{telegram_subscription.chat_id}" 