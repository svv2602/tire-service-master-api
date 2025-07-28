# Создание тестовых заказов для интернет-магазинов
puts "🛒 Создание тестовых заказов интернет-магазинов..."

# Получаем существующие сервисные точки
service_points = ServicePoint.includes(:partner).limit(5)

if service_points.empty?
  puts "❌ Нет доступных сервисных точек для создания заказов"
  return
end

# Массив тестовых клиентов
test_customers = [
  {
    name: "Иванов Иван Иванович",
    phone: "+380671234567"
  },
  {
    name: "Петрова Мария Александровна", 
    phone: "+380501234567"
  },
  {
    name: "Сидоров Петр Петрович",
    phone: "+380931234567"
  },
  {
    name: "Коваленко Олег Васильевич",
    phone: "+380661234567"
  },
  {
    name: "Шевченко Анна Сергеевна",
    phone: "+380971234567"
  }
]

# Массив тестовых товаров
test_goods = [
  {
    artikul: "205/55R16-91V",
    name: "Шина летняя Michelin Energy Saver",
    category: "Шины",
    brand: "Michelin",
    price: 2850,
    quantity: 4,
    bas_id: "SH001"
  },
  {
    artikul: "225/60R17-99H",
    name: "Шина зимняя Continental WinterContact",
    category: "Шины",
    brand: "Continental", 
    price: 3200,
    quantity: 2,
    bas_id: "SH002"
  },
  {
    artikul: "DIL-5W30-4L",
    name: "Масло моторное Shell Helix Ultra 5W-30",
    category: "Масла",
    brand: "Shell",
    price: 890,
    quantity: 1,
    bas_id: "OIL001"
  },
  {
    artikul: "DISC-280MM-VEN",
    name: "Диск тормозной передний Zimmermann",
    category: "Тормозная система",
    brand: "Zimmermann",
    price: 1250,
    quantity: 2,
    bas_id: "BR001"
  },
  {
    artikul: "FILTER-MANN-W712",
    name: "Фильтр масляный Mann-Filter",
    category: "Фильтры",
    brand: "Mann-Filter",
    price: 320,
    quantity: 1,
    bas_id: "FILT001"
  }
]

# Создаем заказы
created_orders = []

20.times do |i|
  service_point = service_points.sample
  customer = test_customers.sample
  
  # Генерируем уникальный ТТН
  ttn = "TTN#{Time.current.strftime('%Y%m%d')}#{sprintf('%04d', i + 1)}"
  
  # Выбираем случайное количество товаров (1-3)
  goods_count = rand(1..3)
  selected_goods = test_goods.sample(goods_count)
  
  # Рассчитываем общую стоимость
  total_amount = selected_goods.sum { |g| g[:price] * g[:quantity] }
  total_quantity = selected_goods.sum { |g| g[:quantity] }
  
  # Случайный статус
  statuses = ['received', 'processing', 'ready', 'delivered', 'canceled']
  weights = [0.3, 0.2, 0.25, 0.2, 0.05] # Вероятности для каждого статуса
  status = statuses.sample
  
  # Даты в зависимости от статуса
  order_date = rand(14.days.ago..Time.current)
  processed_at = status != 'received' ? order_date + rand(1..6).hours : nil
  ready_at = ['ready', 'delivered'].include?(status) ? processed_at + rand(2..12).hours : nil
  delivered_at = status == 'delivered' ? ready_at + rand(1..8).hours : nil
  canceled_at = status == 'canceled' ? order_date + rand(1..24).hours : nil
  
  begin
    order = Order.create!(
      service_point: service_point,
      status: status,
      order_date: order_date,
      ttn: ttn,
      number: "ORD-#{sprintf('%06d', i + 1)}",
      customer_name: customer[:name],
      customer_phone: customer[:phone],
      status_kod: sprintf('%09d', i + 1),
      bas_id: "BAS-#{sprintf('%06d', i + 1)}",
      separate: 1,
      point_name: service_point.name,
      point_id: service_point.id.to_s,
      third_party_point: [true, false].sample,
      ttn_status: status == 'delivered' ? 'Доставлено' : '',
      ttn_status_kod: status == 'delivered' ? 'DELIVERED' : '',
      total_amount: total_amount,
      total_quantity: total_quantity,
      processed_at: processed_at,
      ready_at: ready_at,
      delivered_at: delivered_at,
      canceled_at: canceled_at,
      cancellation_reason: status == 'canceled' ? 'Отказ клиента' : nil,
      notes: i.even? ? "Заметка к заказу №#{i + 1}: особые условия доставки" : nil
    )
    
    # Создаем товары для заказа
    selected_goods.each do |good|
      sum = good[:price] * good[:quantity]
      
      order.order_items.create!(
        artikul: good[:artikul],
        quantity: good[:quantity],
        price: good[:price],
        sum: sum,
        bas_id: good[:bas_id],
        name: good[:name],
        category: good[:category],
        brand: good[:brand]
      )
    end
    
    created_orders << order
    print "."
    
  rescue ActiveRecord::RecordInvalid => e
    puts "\n❌ Ошибка создания заказа #{i + 1}: #{e.message}"
  end
end

puts "\n✅ Создано #{created_orders.count} тестовых заказов"

# Статистика по статусам
status_stats = created_orders.group_by(&:status).transform_values(&:count)
puts "\n📊 Статистика заказов по статусам:"
status_stats.each do |status, count|
  status_label = case status
                when 'received' then 'Получено'
                when 'processing' then 'В обработке'
                when 'ready' then 'Готово к выдаче'
                when 'delivered' then 'Выдано'
                when 'canceled' then 'Отменено'
                else status
                end
  puts "  #{status_label}: #{count}"
end

# Статистика по сервисным точкам
sp_stats = created_orders.group_by(&:service_point).transform_values(&:count)
puts "\n📍 Статистика заказов по сервисным точкам:"
sp_stats.each do |sp, count|
  puts "  #{sp.name} (#{sp.city.name}): #{count}"
end

# Общая статистика
total_revenue = created_orders.select { |o| o.status == 'delivered' }.sum(&:total_amount)
total_items = created_orders.sum(&:total_quantity)

puts "\n💰 Общая статистика:"
puts "  Общая выручка от выданных заказов: #{total_revenue} ₴"
puts "  Общее количество товаров: #{total_items} шт."
puts "  Средний чек: #{created_orders.sum(&:total_amount) / created_orders.count} ₴" 