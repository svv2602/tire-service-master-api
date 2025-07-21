#!/usr/bin/env ruby

puts '📝 ТЕСТИРОВАНИЕ УВЕДОМЛЕНИЙ ОБ ОТЗЫВАХ'
puts '===================================='

begin
  # Создаем тестового пользователя и клиента
  user = User.find_or_create_by(email: 'test_review@example.com') do |u|
    u.first_name = 'Тестовый'
    u.last_name = 'Клиент'
    u.phone = '+380501234567'
    u.password = 'password123'
    u.password_confirmation = 'password123'
  end
  
  client = Client.find_or_create_by(user: user)
  puts "✅ Клиент создан: #{client.user.first_name} #{client.user.last_name}"

  # Находим сервисную точку
  service_point = ServicePoint.first
  unless service_point
    puts "❌ Нет сервисных точек в системе"
    exit
  end
  puts "✅ Сервисная точка: #{service_point.name}"

  # Создаем тестовое бронирование (необязательно для отзыва)
  booking = Booking.find_or_create_by(
    client: client,
    service_point: service_point,
    booking_date: Date.current,
    start_time: Time.current
  ) do |b|
    b.car_type = CarType.first || CarType.create!(name: 'Легковой автомобиль')
    b.car_brand = 'Toyota'
    b.car_model = 'Camry'
    b.license_plate = 'TEST123'
    b.status = 'completed'
    b.skip_notifications = true
  end
  puts "✅ Бронирование создано: ##{booking.id}"

  # Создаем тестовый отзыв
  puts "\n📝 СОЗДАНИЕ ТЕСТОВОГО ОТЗЫВА"
  puts "=========================="
  
  review = Review.new(
    client: client,
    service_point: service_point,
    booking: booking,
    rating: 5,
    comment: 'Отличный сервис! Быстро и качественно!',
    status: 'pending',
    skip_notifications: false  # Включаем уведомления
  )

  if review.save
    puts "✅ Отзыв создан: ##{review.id}"
    puts "   📊 Рейтинг: #{review.rating}/5"
    puts "   💬 Комментарий: #{review.comment}"
    puts "   📋 Статус: #{review.status}"
    puts "   📅 Дата: #{review.created_at.strftime('%d.%m.%Y %H:%M')}"
    
    puts "\n📧 ТЕСТИРОВАНИЕ ИЗМЕНЕНИЯ СТАТУСА"
    puts "================================="
    
    # Тестируем публикацию отзыва
    puts "\n1️⃣ Публикуем отзыв..."
    review.update!(status: 'published')
    puts "   ✅ Статус изменен на: #{review.status}"
    
    # Возвращаем в pending
    review.update!(status: 'pending', skip_notifications: true)
    
    # Тестируем отклонение отзыва
    puts "\n2️⃣ Отклоняем отзыв..."
    review.update!(status: 'rejected', skip_notifications: false)
    puts "   ✅ Статус изменен на: #{review.status}"
    
    puts "\n📊 СТАТИСТИКА УВЕДОМЛЕНИЙ"
    puts "========================"
    puts "Всего отзывов: #{Review.count}"
    puts "Опубликованных: #{Review.published.count}"
    puts "На модерации: #{Review.pending.count}"
    puts "Отклоненных: #{Review.rejected.count}"
    
  else
    puts "❌ Не удалось создать отзыв:"
    review.errors.full_messages.each do |error|
      puts "   - #{error}"
    end
  end

rescue => e
  puts "❌ Ошибка: #{e.message}"
  puts "   #{e.backtrace.first(3).join('\n   ')}"
end

puts "\n🎯 ТЕСТИРОВАНИЕ ЗАВЕРШЕНО!" 