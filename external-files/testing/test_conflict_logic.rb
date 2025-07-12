#!/usr/bin/env ruby
# Простой тест для проверки логики создания конфликтов

puts "🧪 ТЕСТ ЛОГИКИ СОЗДАНИЯ КОНФЛИКТОВ"
puts "=" * 50

# 1. Создаем тестовое бронирование
service_point = ServicePoint.first
client = Client.first
car_type = CarType.first
service_category = ServiceCategory.first

puts "📍 Сервисная точка: #{service_point.name}"
puts "🏪 Статус: #{service_point.work_status}"
puts "🔧 Активных постов: #{service_point.service_posts.active.count}"

# Создаем бронирование на завтра в 10:00
tomorrow = Date.tomorrow
booking = Booking.create!(
  service_point: service_point,
  client: client,
  car_type: car_type,
  service_category: service_category,
  booking_date: tomorrow,
  start_time: Time.parse("10:00"),
  service_recipient_first_name: "Тест",
  service_recipient_last_name: "Тестов",
  service_recipient_phone: "+380671234567",
  status: 'confirmed',
  skip_availability_check: true,
  skip_notifications: true
)

puts "✅ Бронирование создано: ID #{booking.id} на #{booking.booking_date} в #{booking.start_time.strftime('%H:%M')}"

# 2. Проверяем доступность слота ДО изменения статуса
puts "\n🔍 ПРОВЕРКА ДОСТУПНОСТИ СЛОТА ДО ИЗМЕНЕНИЯ:"
available_slots = DynamicAvailabilityService.available_slots_for_category(service_point.id, tomorrow, service_category.id)
puts "📊 Доступных слотов для категории: #{available_slots.count}"
available_slots.first(3).each do |slot|
  puts "  - #{slot[:time]} (#{slot[:available_posts]} постов)"
end

# 3. Меняем статус сервисной точки на temporarily_closed
puts "\n🔄 ИЗМЕНЕНИЕ СТАТУСА СЕРВИСНОЙ ТОЧКИ:"
puts "  Было: #{service_point.work_status}"
service_point.update!(work_status: 'temporarily_closed')
puts "  Стало: #{service_point.work_status}"

# 4. Проверяем доступность слота ПОСЛЕ изменения статуса
puts "\n🔍 ПРОВЕРКА ДОСТУПНОСТИ СЛОТА ПОСЛЕ ИЗМЕНЕНИЯ:"
available_slots_after = DynamicAvailabilityService.available_slots_for_category(service_point.id, tomorrow, service_category.id)
puts "📊 Доступных слотов для категории: #{available_slots_after.count}"
available_slots_after.first(3).each do |slot|
  puts "  - #{slot[:time]} (#{slot[:available_posts]} постов)"
end

# 5. Вручную проверяем конфликт
puts "\n🔍 РУЧНАЯ ПРОВЕРКА КОНФЛИКТА:"
analysis_service = BookingConflictAnalysisService.new(service_point: service_point)
conflict = analysis_service.send(:check_booking_conflict, booking)

if conflict
  puts "✅ Конфликт обнаружен:"
  puts "  - Тип: #{conflict.conflict_type}"
  puts "  - Причина: #{conflict.conflict_reason}"
  puts "  - Статус: #{conflict.status}"
else
  puts "❌ Конфликт не обнаружен"
end

# 6. Проверяем количество конфликтов в БД
conflicts_count = BookingConflict.count
puts "\n📊 Общее количество конфликтов в БД: #{conflicts_count}"

# 7. Очистка
puts "\n🧹 Очистка тестовых данных..."
BookingConflict.where(booking: booking).destroy_all
booking.destroy
service_point.update!(work_status: 'working')

puts "✅ Тест завершен!" 