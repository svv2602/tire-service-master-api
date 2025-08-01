# Создание тестовых поставщиков для демонстрации системы

puts "🔄 Создание тестовых поставщиков..."

# Очищаем существующие данные
SupplierTireProduct.delete_all
SupplierPriceVersion.delete_all
Supplier.delete_all

# Создаем тестовых поставщиков
suppliers_data = [
  {
    firm_id: '23951',
    name: 'Інтернет-магазин шин та дисків Prokoleso.ua',
    priority: 1
  },
  {
    firm_id: '15678',
    name: 'ШинТорг - оптовый поставщик шин',
    priority: 2
  },
  {
    firm_id: '98765',
    name: 'Колесо-Центр - сеть магазинов шин',
    priority: 3
  }
]

suppliers = []
suppliers_data.each do |data|
  supplier = Supplier.create!(data)
  suppliers << supplier
  puts "✅ Создан поставщик: #{supplier.name} (ID: #{supplier.firm_id})"
  puts "   API ключ: #{supplier.api_key}"
end

# Создаем тестовые товары для демонстрации
puts "\n🔄 Создание тестовых товаров..."

test_products = [
  # Goodyear зимние шины
  {
    external_id: '00000012536',
    brand: 'Goodyear',
    model: 'Cargo UltraGrip',
    name: 'Goodyear Cargo UltraGrip (195/65R16C 104T)',
    width: 195,
    height: 65,
    diameter: '16C',
    load_index: '104',
    speed_index: 'T',
    season: 'winter',
    price_uah: 6375.00,
    stock_status: 'В наявності',
    description: 'Швидка доставка до будь-якої точки України. Гарантія високої якості та величезний вибір зимових шин за найнижчими цінами.',
    image_url: 'https://prokoleso.ua/upload/iblock/e8f/Ultra_grip_cargo.png',
    product_url: 'https://prokoleso.ua/ua/shiny/goodyear-ultra-grip-cargo-195-65r16c-104-102t.html',
    country: 'Турция',
    year_week: '24р 02тиж'
  },
  {
    external_id: '00000013355',
    brand: 'Goodyear',
    model: 'Cargo UltraGrip',
    name: 'Goodyear Cargo UltraGrip (205/75R16C 110R)',
    width: 205,
    height: 75,
    diameter: '16C',
    load_index: '110',
    speed_index: 'R',
    season: 'winter',
    price_uah: 6375.00,
    stock_status: 'В наявності',
    description: 'Швидка доставка до будь-якої точки України. Гарантія високої якості та величезний вибір зимових шин за найнижчими цінами.',
    image_url: 'https://prokoleso.ua/upload/iblock/e8f/Ultra_grip_cargo.png',
    product_url: 'https://prokoleso.ua/ua/shiny/goodyear-ultra-grip-cargo-205-75r16c-110-108r.html',
    country: 'Турция',
    year_week: '24р 26тиж'
  },
  # Michelin летние шины
  {
    external_id: 'MICH_185_60_15',
    brand: 'Michelin',
    model: 'Energy Saver',
    name: 'Michelin Energy Saver (185/60R15 84H)',
    width: 185,
    height: 60,
    diameter: '15',
    load_index: '84',
    speed_index: 'H',
    season: 'summer',
    price_uah: 3250.00,
    stock_status: 'В наявності',
    description: 'Летние шины Michelin Energy Saver - экономия топлива и отличное сцепление.',
    image_url: 'https://example.com/michelin_energy_saver.jpg',
    product_url: 'https://example.com/michelin-energy-saver-185-60r15',
    country: 'Франция',
    year_week: '24р 15тиж'
  },
  # Continental всесезонные
  {
    external_id: 'CONT_195_65_15',
    brand: 'Continental',
    model: 'AllSeasonContact',
    name: 'Continental AllSeasonContact (195/65R15 91H)',
    width: 195,
    height: 65,
    diameter: '15',
    load_index: '91',
    speed_index: 'H',
    season: 'all_season',
    price_uah: 4100.00,
    stock_status: 'В наявності',
    description: 'Всесезонные шины Continental для комфортной езды круглый год.',
    image_url: 'https://example.com/continental_allseason.jpg',
    product_url: 'https://example.com/continental-allseasoncontact-195-65r15',
    country: 'Германия',
    year_week: '24р 20тиж'
  }
]

# Создаем товары для каждого поставщика с разными ценами
suppliers.each_with_index do |supplier, index|
  test_products.each do |product_data|
    # Варьируем цены у разных поставщиков
    price_multiplier = 1.0 + (index * 0.1) # 1.0, 1.1, 1.2
    adjusted_price = (product_data[:price_uah] * price_multiplier).round(2)
    
    product = supplier.supplier_tire_products.create!(
      product_data.merge(
        price_uah: adjusted_price,
        external_id: "#{product_data[:external_id]}_#{supplier.firm_id}"
      )
    )
    
    puts "  ✅ Создан товар: #{product.name} - #{product.formatted_price} (#{supplier.name})"
  end
end

# Создаем версии прайсов
puts "\n🔄 Создание версий прайсов..."

suppliers.each do |supplier|
  version = supplier.supplier_price_versions.create!(
    products_count: supplier.supplier_tire_products.count,
    processed_count: supplier.supplier_tire_products.count,
    errors_count: 0,
    processing_time_ms: rand(1000..5000),
    file_checksum: Digest::SHA256.hexdigest("test_data_#{supplier.firm_id}")
  )
  
  puts "  ✅ Создана версия прайса: #{version.version} для #{supplier.name}"
end

puts "\n✅ Тестовые данные созданы успешно!"
puts "\n📊 Статистика:"
puts "   Поставщиков: #{Supplier.count}"
puts "   Товаров: #{SupplierTireProduct.count}"
puts "   Версий прайсов: #{SupplierPriceVersion.count}"

puts "\n🔑 API ключи поставщиков:"
Supplier.all.each do |supplier|
  puts "   #{supplier.name}: #{supplier.api_key}"
end