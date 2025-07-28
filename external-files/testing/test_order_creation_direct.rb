require 'json'

puts "🧪 Прямое тестирование создания заказа..."

# Читаем пример заказа
order_data = JSON.parse(File.read('external-files/testing/example_incoming_order.json')).first
puts "📄 Данные заказа загружены: #{order_data['ttn']}"

# Находим сервисную точку
service_point = ServicePoint.find_by(name: 'ШиноСервіс Експрес на Хрещатику')
puts "🏪 Сервисная точка: #{service_point.name} (ID: #{service_point.id})"

# Создаем заказ напрямую
puts "\n🔍 Создание заказа напрямую..."

order = Order.new(
  service_point: service_point,
  status: 'received',
  order_date: DateTime.parse('29.05.2025 13:27:43'),
  ttn: order_data['ttn'],
  number: order_data['number'],
  customer_name: order_data['klient'],
  customer_phone: '+380667324633',
  status_kod: order_data['status_kod'],
  bas_id: order_data['bas_id'],
  separate: order_data['separate'] || 1,
  point_name: order_data['point'],
  point_id: order_data['point_id'],
  third_party_point: order_data['third_party_point'] == "Да",
  ttn_status: order_data['ttn_status'],
  ttn_status_kod: order_data['ttn_status_kod']
)

# Добавляем товары
order_data['goods'].each do |good_data|
  order.order_items.build(
    artikul: good_data['artikul'],
    quantity: good_data['quantity'],
    price: good_data['price'],
    sum: good_data['sum'],
    bas_id: good_data['bas_id'],
    name: good_data['name'],
    category: good_data['category'],
    brand: good_data['brand']
  )
end

puts "Заказ подготовлен:"
puts "  TTN: #{order.ttn}"
puts "  Клиент: #{order.customer_name}"
puts "  Товаров: #{order.order_items.size}"

# Проверяем валидность
puts "\n🔍 Проверка валидности:"
puts "Valid: #{order.valid?}"

if !order.valid?
  puts "❌ Ошибки валидации:"
  order.errors.full_messages.each { |msg| puts "  - #{msg}" }
  
  puts "\n🔍 Детальные ошибки по полям:"
  order.errors.each do |error|
    puts "  #{error.attribute}: #{error.message}"
  end
end

# Пытаемся сохранить
puts "\n💾 Попытка сохранения..."
if order.save
  puts "✅ Заказ успешно сохранен!"
  puts "  ID: #{order.id}"
  puts "  TTN: #{order.ttn}"
  puts "  Товаров в БД: #{order.order_items.count}"
  
  order.order_items.each do |item|
    puts "    - #{item.artikul}: #{item.name} (#{item.quantity} шт.)"
  end
else
  puts "❌ Ошибка сохранения:"
  order.errors.full_messages.each { |msg| puts "  - #{msg}" }
end 