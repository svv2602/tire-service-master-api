#!/usr/bin/env ruby
# Тестовый скрипт для проверки системы автоматического создания конфликтов бронирований

puts "🧪 ТЕСТИРОВАНИЕ СИСТЕМЫ КОНФЛИКТОВ БРОНИРОВАНИЙ"
puts "=" * 60

# 1. Найдем существующую сервисную точку и пост
service_point = ServicePoint.first
puts "📍 Тестируем сервисную точку: #{service_point.name} (ID: #{service_point.id})"

service_post = service_point.service_posts.active.first
puts "🏪 Тестируем пост: #{service_post.name} (ID: #{service_post.id})" if service_post

# 2. Создадим тестовое бронирование на завтра
tomorrow = Date.tomorrow
booking_time = Time.parse("10:00")
client = Client.first
car_type = CarType.first
service_category = ServiceCategory.first

puts "\n📅 Создаем тестовое бронирование:"
puts "  - Дата: #{tomorrow}"
puts "  - Время: #{booking_time.strftime('%H:%M')}"
puts "  - Клиент: #{client.user.first_name} #{client.user.last_name}" if client
puts "  - Категория: #{service_category.name}" if service_category

# Создаем бронирование с обработкой ошибок
begin
  booking = Booking.create!(
    service_point: service_point,
    client: client,
    car_type: car_type,
    service_category: service_category,
    booking_date: tomorrow,
    start_time: booking_time,
    end_time: booking_time + 1.hour,
    service_recipient_first_name: client.user.first_name,
    service_recipient_last_name: client.user.last_name,
    service_recipient_phone: client.user.phone,
    service_recipient_email: client.user.email,
    status: 'confirmed',
    skip_availability_check: true,  # Пропускаем проверку доступности для тестов
    skip_notifications: true        # Пропускаем уведомления для тестов
  )
  
  puts "✅ Бронирование создано: ID #{booking.id}"
rescue ActiveRecord::RecordInvalid => e
  puts "❌ Ошибка создания бронирования: #{e.message}"
  puts "Детали ошибок:"
  e.record.errors.full_messages.each { |msg| puts "  - #{msg}" }
  
  # Попробуем создать минимальное бронирование
  booking = Booking.new(
    service_point: service_point,
    client: client,
    car_type: car_type,
    service_category: service_category,
    booking_date: tomorrow,
    start_time: booking_time,
    service_recipient_first_name: "Тест",
    service_recipient_last_name: "Тестов",
    service_recipient_phone: "+380671234567",
    status: 'confirmed',
    skip_availability_check: true,
    skip_notifications: true
  )
  
  if booking.save
    puts "✅ Минимальное бронирование создано: ID #{booking.id}"
  else
    puts "❌ Не удалось создать даже минимальное бронирование"
    booking.errors.full_messages.each { |msg| puts "  - #{msg}" }
    exit 1
  end
end

# 3. Проверим текущие конфликты
initial_conflicts_count = BookingConflict.count
puts "\n📊 Количество конфликтов до изменений: #{initial_conflicts_count}"

# 4. Тестируем изменение статуса сервисной точки
puts "\n🔄 ТЕСТ 1: Изменение статуса сервисной точки"
puts "  Текущий статус: #{service_point.work_status}"
puts "  Меняем на: temporarily_closed"

service_point.update!(work_status: 'temporarily_closed')
sleep(1) # Даем время для выполнения Job

new_conflicts_count = BookingConflict.count
puts "  📊 Конфликтов после изменения: #{new_conflicts_count}"
puts "  #{new_conflicts_count > initial_conflicts_count ? '✅ Конфликт создан!' : '❌ Конфликт не создан'}"

# 5. Проверим созданные конфликты
recent_conflicts = BookingConflict.where('created_at > ?', 5.minutes.ago)
puts "\n📋 Последние конфликты:"
recent_conflicts.each do |conflict|
  puts "  - ID: #{conflict.id}, Тип: #{conflict.conflict_type}, Причина: #{conflict.conflict_reason}"
  puts "    Бронирование: #{conflict.booking.id} (#{conflict.booking.booking_date} #{conflict.booking.start_time.strftime('%H:%M')})"
end

# 6. Тестируем изменение статуса поста
if service_post
  puts "\n🔄 ТЕСТ 2: Изменение статуса поста"
  puts "  Текущий статус: #{service_post.is_active ? 'активен' : 'неактивен'}"
  puts "  Меняем на: неактивен"
  
  service_post.update!(is_active: false)
  sleep(1)
  
  post_conflicts_count = BookingConflict.count
  puts "  📊 Конфликтов после изменения поста: #{post_conflicts_count}"
  puts "  #{post_conflicts_count > new_conflicts_count ? '✅ Конфликт создан!' : '❌ Конфликт не создан'}"
end

# 7. Тестируем создание сезонного расписания
puts "\n🔄 ТЕСТ 3: Создание сезонного расписания"
seasonal_schedule = SeasonalSchedule.create!(
  service_point: service_point,
  name: "Тестовое расписание",
  start_date: tomorrow,
  end_date: tomorrow + 7.days,
  working_hours: {
    "monday" => { "is_working_day" => false },
    "tuesday" => { "is_working_day" => false },
    "wednesday" => { "is_working_day" => false },
    "thursday" => { "is_working_day" => false },
    "friday" => { "is_working_day" => false },
    "saturday" => { "is_working_day" => false },
    "sunday" => { "is_working_day" => false }
  },
  priority: 1,
  is_active: true
)

sleep(1)

seasonal_conflicts_count = BookingConflict.count
puts "  📊 Конфликтов после создания сезонного расписания: #{seasonal_conflicts_count}"
puts "  #{seasonal_conflicts_count > post_conflicts_count ? '✅ Конфликт создан!' : '❌ Конфликт не создан'}"

# 8. Итоговая статистика
puts "\n📊 ИТОГОВАЯ СТАТИСТИКА:"
puts "  Начальное количество конфликтов: #{initial_conflicts_count}"
puts "  Финальное количество конфликтов: #{BookingConflict.count}"
puts "  Создано новых конфликтов: #{BookingConflict.count - initial_conflicts_count}"

# 9. Показываем все новые конфликты
new_conflicts = BookingConflict.where('created_at > ?', 5.minutes.ago)
puts "\n📋 ВСЕ НОВЫЕ КОНФЛИКТЫ:"
new_conflicts.each do |conflict|
  puts "  🔸 ID: #{conflict.id}"
  puts "    Тип: #{conflict.conflict_type_human}"
  puts "    Причина: #{conflict.conflict_reason}"
  puts "    Бронирование: #{conflict.booking.id} (#{conflict.booking.booking_date} #{conflict.booking.start_time.strftime('%H:%M')})"
  puts "    Создан: #{conflict.created_at.strftime('%H:%M:%S')}"
  puts
end

# 10. Очистка тестовых данных
puts "🧹 Очистка тестовых данных..."
booking.destroy
seasonal_schedule.destroy
service_point.update!(work_status: 'working') # Восстанавливаем статус
service_post.update!(is_active: true) if service_post # Восстанавливаем статус поста
new_conflicts.destroy_all # Удаляем созданные конфликты

puts "✅ Тестирование завершено!" 