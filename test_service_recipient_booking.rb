#!/usr/bin/env ruby

# Тест создания бронирования с данными получателя услуги
require 'net/http'
require 'json'
require 'uri'
require 'date'

# Конфигурация
API_BASE_URL = 'http://localhost:8000'
API_ENDPOINT = '/api/v1/client_bookings'

# Данные для создания бронирования
booking_data = {
  booking: {
    service_point_id: 1,
    booking_date: '2025-06-30', # Понедельник - рабочий день
    start_time: '10:00',
    notes: 'Тестовое бронирование с получателем услуги',
    # Данные получателя услуги
    service_recipient_first_name: 'Анна',
    service_recipient_last_name: 'Петрова',
    service_recipient_phone: '+380671234888', # Уникальный номер
    service_recipient_email: 'anna.petrova888@example.com'
  },
  car: {
    car_type_id: 1,
    license_plate: 'АА1234ВВ',
    car_brand: 'Toyota',
    car_model: 'Camry'
  },
  client: {
    first_name: 'Иван',
    last_name: 'Иванов',
    phone: '+380671234999', # Уникальный номер
    email: 'ivan.ivanov999@example.com'
  },
  services: []
}

puts "=== ТЕСТ СОЗДАНИЯ БРОНИРОВАНИЯ С ПОЛУЧАТЕЛЕМ УСЛУГИ ==="
puts "URL: #{API_BASE_URL}#{API_ENDPOINT}"
puts "Данные:"
puts JSON.pretty_generate(booking_data)
puts

# Создание HTTP запроса
uri = URI("#{API_BASE_URL}#{API_ENDPOINT}")
http = Net::HTTP.new(uri.host, uri.port)
request = Net::HTTP::Post.new(uri)
request['Content-Type'] = 'application/json'
request.body = booking_data.to_json

begin
  # Отправка запроса
  puts "Отправляем запрос..."
  response = http.request(request)
  
  puts "Статус ответа: #{response.code} #{response.message}"
  puts "Заголовки ответа:"
  response.each_header { |key, value| puts "  #{key}: #{value}" }
  puts
  
  if response.body
    puts "Тело ответа:"
    begin
      parsed_response = JSON.parse(response.body)
      puts JSON.pretty_generate(parsed_response)
    rescue JSON::ParserError
      puts response.body
    end
  end
  
  # Анализ результата
  case response.code.to_i
  when 201
    puts "\n✅ УСПЕХ: Бронирование создано!"
    parsed = JSON.parse(response.body)
    if parsed['service_recipient']
      puts "✅ Данные получателя услуги сохранены:"
      puts "   Имя: #{parsed['service_recipient']['first_name']} #{parsed['service_recipient']['last_name']}"
      puts "   Телефон: #{parsed['service_recipient']['phone']}"
      puts "   Email: #{parsed['service_recipient']['email']}"
    else
      puts "⚠️  Данные получателя услуги отсутствуют в ответе"
    end
  when 422
    puts "\n❌ ОШИБКА ВАЛИДАЦИИ:"
    parsed = JSON.parse(response.body)
    if parsed['details']
      parsed['details'].each { |detail| puts "   - #{detail}" }
    else
      puts "   #{parsed['error']}"
    end
  when 400
    puts "\n❌ ОШИБКА ЗАПРОСА:"
    puts "   #{JSON.parse(response.body)['error']}"
  else
    puts "\n❌ НЕОЖИДАННАЯ ОШИБКА:"
    puts "   Код: #{response.code}"
    puts "   Сообщение: #{response.message}"
  end
  
rescue => e
  puts "❌ ОШИБКА СОЕДИНЕНИЯ: #{e.message}"
  puts "Убедитесь, что backend сервер запущен на #{API_BASE_URL}"
end

puts "\n=== КОНЕЦ ТЕСТА ===" 