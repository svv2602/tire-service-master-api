require 'json'

puts "🧪 Тестирование обработки заказов..."

# Читаем пример заказа
order_data = JSON.parse(File.read('external-files/testing/example_incoming_order.json'))
puts "📄 Данные заказа загружены"

# Находим сервисную точку
service_point = ServicePoint.find_by(name: 'ШиноСервіс Експрес на Хрещатику')
puts "🏪 Сервисная точка: #{service_point&.name} (ID: #{service_point&.id})"

# Создаем процессор
processor = OrderProcessorService.new(order_data.to_json, service_point)

# Проверяем валидацию
puts "\n🔍 Валидация процессора:"
puts "- raw_data present: #{processor.raw_data.present?}"
puts "- service_point present: #{processor.service_point.present?}"
puts "- valid?: #{processor.valid?}"

if !processor.valid?
  puts "\n❌ Ошибки валидации:"
  processor.errors.full_messages.each { |msg| puts "  - #{msg}" }
  exit
end

# Обрабатываем заказ
puts "\n⚙️ Обработка заказа..."
if processor.process
  puts "✅ Заказ успешно создан!"
  puts "Создано заказов: #{processor.orders.count}"
  
  processor.orders.each do |order|
    puts "\n📦 Заказ ID: #{order.id}"
    puts "  TTN: #{order.ttn}"
    puts "  Клиент: #{order.customer_name}"
    puts "  Телефон: #{order.customer_phone}"
    puts "  Сумма: #{order.total_amount} ₴"
    puts "  Товаров: #{order.order_items.count}"
    
    order.order_items.each do |item|
      puts "    - #{item.artikul}: #{item.name} (#{item.quantity} шт. x #{item.price} ₴ = #{item.sum} ₴)"
    end
  end
else
  puts "❌ Ошибка создания заказа:"
  processor.errors.full_messages.each { |msg| puts "  - #{msg}" }
end 