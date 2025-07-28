require 'json'

puts "🧪 Детальное тестирование обработки заказов..."

# Читаем пример заказа
order_data = JSON.parse(File.read('external-files/testing/example_incoming_order.json'))
puts "📄 Данные заказа: #{order_data.first.keys.join(', ')}"

# Находим сервисную точку
service_point = ServicePoint.find_by(name: 'ШиноСервіс Експрес на Хрещатику')
puts "🏪 Сервисная точка: #{service_point&.name} (ID: #{service_point&.id})"

# Создаем процессор
processor = OrderProcessorService.new(order_data.to_json, service_point)

# Проверяем внутренние методы
puts "\n🔍 Проверка парсинга данных:"
begin
  parsed_data = processor.send(:parse_json_data)
  puts "✅ Данные успешно распарсены"
  puts "Количество заказов в данных: #{parsed_data.size}"
  puts "Первый заказ: TTN=#{parsed_data.first[:ttn]}, товаров=#{parsed_data.first[:goods]&.size || 0}"
rescue => e
  puts "❌ Ошибка парсинга: #{e.message}"
  exit
end

# Проверяем создание одного заказа
puts "\n🔍 Проверка создания заказа:"
begin
  order_data_single = parsed_data.first
  
  # Проверяем поиск сервисной точки
  target_service_point = processor.send(:find_service_point, order_data_single)
  puts "Найдена сервисная точка: #{target_service_point&.name}"
  
  # Проверяем маппинг статуса
  mapped_status = processor.send(:map_external_status, order_data_single[:status])
  puts "Статус: #{order_data_single[:status]} -> #{mapped_status}"
  
  # Проверяем парсинг даты
  parsed_date = processor.send(:parse_order_date, order_data_single[:date])
  puts "Дата: #{order_data_single[:date]} -> #{parsed_date}"
  
  # Проверяем нормализацию телефона
  normalized_phone = processor.send(:normalize_phone, order_data_single[:phone])
  puts "Телефон: #{order_data_single[:phone]} -> #{normalized_phone}"
  
  # Пытаемся создать заказ
  order = processor.send(:create_single_order, order_data_single)
  if order
    puts "✅ Заказ создан: ID=#{order.id}, TTN=#{order.ttn}"
    puts "  Товаров: #{order.order_items.count}"
  else
    puts "❌ Заказ не создан"
  end
  
rescue => e
  puts "❌ Ошибка создания заказа: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end

# Полная обработка
puts "\n⚙️ Полная обработка заказа..."
if processor.process
  puts "✅ Процесс завершен успешно"
  puts "Создано заказов: #{processor.orders.count}"
  
  if processor.orders.any?
    processor.orders.each do |order|
      puts "\n📦 Заказ ID: #{order.id}"
      puts "  TTN: #{order.ttn}"
      puts "  Статус: #{order.status}"
      puts "  Товаров: #{order.order_items.count}"
    end
  else
    puts "⚠️ Заказы не созданы, но ошибок нет"
  end
else
  puts "❌ Ошибка процесса:"
  processor.errors.full_messages.each { |msg| puts "  - #{msg}" }
end 