# Создание типов автомобилей
puts "Creating car types..."
car_types = [
  { name: 'Легковой автомобиль', description: 'Стандартный легковой автомобиль для перевозки пассажиров', is_active: true },
  { name: 'Кроссовер', description: 'Автомобиль с элементами дизайна внедорожника, но построенный на платформе легкового автомобиля', is_active: true },
  { name: 'Внедорожник', description: 'Спортивно-утилитарный автомобиль, сочетающий характеристики легкового автомобиля и внедорожника', is_active: true },
  { name: 'Минивен', description: 'Микроавтобус для пассажирских перевозок с двумя или тремя рядами сидений', is_active: true },
  { name: 'Микроавтобус', description: 'Автобус малой вместимости для перевозки до 20 пассажиров', is_active: true },
  { name: 'Легкий коммерческий транспорт', description: 'Коммерческие автомобили для перевозки грузов и пассажиров (Газель, Форд Транзит, Ивеко Дейли)', is_active: true }
]

car_types.each_with_index do |car_type, idx|
  ct = CarType.find_or_create_by(name: car_type[:name]) do |ct|
    ct.description = car_type[:description]
    ct.is_active = car_type[:is_active]
  end
  ct.update(description: car_type[:description], is_active: car_type[:is_active])
  ct.update(sort_order: idx + 1) if ct.respond_to?(:sort_order)
end
