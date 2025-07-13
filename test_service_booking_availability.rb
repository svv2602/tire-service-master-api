#!/usr/bin/env ruby

# Тест возможности создания служебных бронирований без проверки доступности
puts "🚀 Тестирование создания служебных бронирований без проверки доступности постов"

# Найдем пользователей
admin_user = User.joins(:role).where(user_roles: { name: 'admin' }).first
client_user = User.joins(:role).where(user_roles: { name: 'client' }).first

admin_client = admin_user&.client || Client.create!(user: admin_user, preferred_notification_method: 'email')
client_client = client_user&.client

service_point = ServicePoint.first
car_type = CarType.first

puts "\n📊 Тестовые данные:"
puts "Service Point: #{service_point.name} (ID: #{service_point.id})"
puts "Car Type: #{car_type.name} (ID: #{car_type.id})"

# Проверим количество постов на сервисной точке
posts_count = service_point.service_posts.active.count
puts "Количество активных постов: #{posts_count}"

# Создадим бронирования на одно время чтобы "заполнить" все посты
test_date = Date.tomorrow
test_time = '14:00:00'

puts "\n🧪 Создание #{posts_count} обычных бронирований для заполнения всех постов..."

# Создаем бронирования для заполнения всех постов
posts_count.times do |i|
  booking = Booking.new(
    client: client_client,
    service_point: service_point,
    car_type: car_type,
    booking_date: test_date,
    start_time: test_time,
    end_time: '15:00:00',
    service_recipient_first_name: 'Клиент',
    service_recipient_last_name: "Тест#{i+1}",
    service_recipient_phone: "+38050123456#{i}",
    service_recipient_email: "test#{i}@client.com",
    status: 'pending'
  )
  
  if booking.save
    puts "✅ Обычное бронирование #{i+1} создано (ID: #{booking.id})"
  else
    puts "❌ Ошибка создания бронирования #{i+1}: #{booking.errors.full_messages.join(', ')}"
  end
end

# Проверим доступность через DynamicAvailabilityService
puts "\n🔍 Проверка доступности через DynamicAvailabilityService:"
available_slots = DynamicAvailabilityService.available_slots_for_date(service_point.id, test_date)
available_at_test_time = available_slots.select { |slot| slot[:start_time] == test_time.gsub(':00', '') }

puts "Доступные слоты на #{test_time}: #{available_at_test_time.count}"

if available_at_test_time.empty?
  puts "✅ Все посты заняты - идеальные условия для теста!"
  
  # Попробуем создать обычное бронирование (должно не получиться)
  puts "\n🧪 Попытка создания обычного бронирования на занятое время..."
  regular_booking = Booking.new(
    client: client_client,
    service_point: service_point,
    car_type: car_type,
    booking_date: test_date,
    start_time: test_time,
    end_time: '15:00:00',
    service_recipient_first_name: 'Клиент',
    service_recipient_last_name: 'Обычный',
    service_recipient_phone: '+380501234999',
    service_recipient_email: 'regular@client.com',
    status: 'pending'
  )
  
  if regular_booking.save
    puts "❌ ОШИБКА: Обычное бронирование не должно было создаться!"
  else
    puts "✅ Обычное бронирование отклонено (как и ожидалось)"
    puts "   Ошибки: #{regular_booking.errors.full_messages.join(', ')}"
  end
  
  # Попробуем создать служебное бронирование (должно получиться)
  puts "\n🧪 Попытка создания служебного бронирования на занятое время..."
  service_booking = Booking.new(
    client: admin_client,
    service_point: service_point,
    car_type: car_type,
    booking_date: test_date,
    start_time: test_time,
    end_time: '15:00:00',
    service_recipient_first_name: 'Админ',
    service_recipient_last_name: 'Служебное',
    service_recipient_phone: '+380501234777',
    service_recipient_email: 'service@admin.com',
    status: 'pending'
  )
  
  if service_booking.save
    puts "✅ УСПЕХ: Служебное бронирование создано успешно!"
    puts "   ID: #{service_booking.id}"
    puts "   is_service_booking: #{service_booking.is_service_booking}"
    puts "   Валидация доступности пропущена: #{service_booking.is_service_booking}"
  else
    puts "❌ ОШИБКА: Служебное бронирование должно было создаться!"
    puts "   Ошибки: #{service_booking.errors.full_messages.join(', ')}"
  end
else
  puts "⚠️ Не все посты заняты, тест не показательный"
end

# Итоговая статистика
puts "\n📈 Итоговая статистика:"
total_bookings = Booking.where(booking_date: test_date, start_time: test_time).count
service_bookings = Booking.where(booking_date: test_date, start_time: test_time, is_service_booking: true).count
regular_bookings = Booking.where(booking_date: test_date, start_time: test_time, is_service_booking: false).count

puts "Всего бронирований на #{test_time}: #{total_bookings}"
puts "Служебных бронирований: #{service_bookings}"
puts "Обычных бронирований: #{regular_bookings}"
puts "Количество постов: #{posts_count}"

if total_bookings > posts_count
  puts "✅ ТЕСТ ПРОЙДЕН: Служебные бронирования могут создаваться сверх лимита постов!"
else
  puts "❌ ТЕСТ НЕ ПРОЙДЕН: Что-то пошло не так"
end

puts "\n🎯 Тест завершен!" 