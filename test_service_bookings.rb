#!/usr/bin/env ruby

# Тест функциональности служебных бронирований
puts "🚀 Тестирование функциональности служебных бронирований"

# Найдем пользователей с разными ролями
admin_user = User.joins(:role).where(user_roles: { name: 'admin' }).first
client_user = User.joins(:role).where(user_roles: { name: 'client' }).first
partner_user = User.joins(:role).where(user_roles: { name: 'partner' }).first

puts "\n📊 Найденные пользователи:"
puts "Admin: #{admin_user&.email} (ID: #{admin_user&.id})"
puts "Client: #{client_user&.email} (ID: #{client_user&.id})"
puts "Partner: #{partner_user&.email} (ID: #{partner_user&.id})"

# Проверим роли
puts "\n🔍 Проверка ролей:"
puts "Admin role check: #{admin_user&.admin?}"
puts "Client role check: #{client_user&.client?}"
puts "Partner role check: #{partner_user&.partner?}"

# Найдем клиентов для этих пользователей
admin_client = admin_user&.client
client_client = client_user&.client
partner_client = partner_user&.partner

puts "\n👥 Связанные записи:"
puts "Admin client: #{admin_client&.id}"
puts "Client client: #{client_client&.id}"
puts "Partner client: #{partner_client&.id}"

# Создадим клиента для администратора если его нет
if admin_user && !admin_client
  puts "\n🔧 Создание клиента для администратора..."
  admin_client = Client.create!(
    user: admin_user,
    preferred_notification_method: 'email'
  )
  puts "✅ Клиент создан для администратора (ID: #{admin_client.id})"
end

# Найдем сервисную точку и тип автомобиля для тестирования
service_point = ServicePoint.first
car_type = CarType.first

puts "\n🏢 Тестовые данные:"
puts "Service Point: #{service_point&.name} (ID: #{service_point&.id})"
puts "Car Type: #{car_type&.name} (ID: #{car_type&.id})"

if admin_client && service_point && car_type
  puts "\n🧪 Создание тестового служебного бронирования от администратора..."
  
  booking = Booking.new(
    client: admin_client,
    service_point: service_point,
    car_type: car_type,
    booking_date: Date.tomorrow,
    start_time: '09:00:00',
    end_time: '10:00:00',
    service_recipient_first_name: 'Тест',
    service_recipient_last_name: 'Администратор',
    service_recipient_phone: '+380501234567',
    service_recipient_email: 'test@admin.com',
    status: 'pending'
  )
  
  if booking.save
    puts "✅ Служебное бронирование создано успешно!"
    puts "   ID: #{booking.id}"
    puts "   is_service_booking: #{booking.is_service_booking}"
    puts "   service_booking?: #{booking.service_booking?}"
  else
    puts "❌ Ошибка создания бронирования:"
    booking.errors.full_messages.each { |msg| puts "   - #{msg}" }
  end
end

if client_client && service_point && car_type
  puts "\n🧪 Создание тестового обычного бронирования от клиента..."
  
  booking = Booking.new(
    client: client_client,
    service_point: service_point,
    car_type: car_type,
    booking_date: Date.tomorrow,
    start_time: '11:00:00',
    end_time: '12:00:00',
    service_recipient_first_name: 'Тест',
    service_recipient_last_name: 'Клиент',
    service_recipient_phone: '+380501234568',
    service_recipient_email: 'test@client.com',
    status: 'pending'
  )
  
  if booking.save
    puts "✅ Обычное бронирование создано успешно!"
    puts "   ID: #{booking.id}"
    puts "   is_service_booking: #{booking.is_service_booking}"
    puts "   service_booking?: #{booking.service_booking?}"
  else
    puts "❌ Ошибка создания бронирования:"
    booking.errors.full_messages.each { |msg| puts "   - #{msg}" }
  end
end

puts "\n📈 Статистика бронирований:"
puts "Всего бронирований: #{Booking.count}"
puts "Служебных бронирований: #{Booking.service_bookings.count}"
puts "Обычных бронирований: #{Booking.regular_bookings.count}"

# Покажем последние бронирования
puts "\n📋 Последние бронирования:"
Booking.last(3).each do |booking|
  puts "  ID: #{booking.id}, Служебное: #{booking.is_service_booking}, Клиент: #{booking.client&.user&.email}"
end

puts "\n🎯 Тест завершен!" 