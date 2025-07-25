# Находим клиента ID 18
client = Client.find_by(id: 18)
if client
  puts "Клиент найден: #{client.user.first_name} #{client.user.last_name}"
  
  # Создаем тестовое бронирование
  booking = Booking.create!(
    client: client,
    service_point_id: 1,
    service_category_id: 1,
    car_type_id: 1,
    booking_date: Date.tomorrow,
    start_time: '10:00',
    car_brand: 'Toyota',
    car_model: 'Camry',
    license_plate: 'AA1234BB',
    service_recipient_first_name: client.user.first_name,
    service_recipient_last_name: client.user.last_name,
    service_recipient_phone: client.user.phone,
    notes: 'Тестовое бронирование для проверки отображения',
    status: 'pending'
  )
  
  puts "Бронирование создано: ID=#{booking.id}"
else
  puts 'Клиент ID 18 не найден'
end 