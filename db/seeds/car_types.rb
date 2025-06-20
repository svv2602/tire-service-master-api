# Create car types
puts "Creating car types..."
car_types = [
  { name: 'Седан', description: 'Стандартный легковой автомобиль с отдельным багажником', is_active: true },
  { name: 'Хэтчбек', description: 'Автомобиль с задней дверью, открывающейся вверх, багажник интегрирован в пассажирский салон', is_active: true },
  { name: 'Внедорожник', description: 'Спортивно-утилитарный автомобиль, сочетающий характеристики легкового автомобиля и внедорожника', is_active: true },
  { name: 'Кроссовер', description: 'Автомобиль с элементами дизайна внедорожника, но построенный на платформе легкового автомобиля', is_active: true },
  { name: 'Пикап', description: 'Легкий грузовик с открытой грузовой площадкой сзади', is_active: true },
  { name: 'Минивэн', description: 'Микроавтобус для пассажирских перевозок с двумя или тремя рядами сидений', is_active: true },
  { name: 'Купе', description: 'Двухдверный автомобиль с фиксированной крышей и покатой задней частью', is_active: true },
  { name: 'Кабриолет', description: 'Автомобиль со складывающейся или съемной крышей', is_active: true },
  { name: 'Универсал', description: 'Автомобиль с расширенной грузовой зоной, похожий на хэтчбек, но с большим грузовым пространством', is_active: true },
  { name: 'Фургон', description: 'Тип дорожного транспортного средства для перевозки товаров или людей', is_active: true },
  { name: 'Легкий коммерческий транспорт', description: 'Коммерческие автомобили для перевозки грузов и пассажиров (Газель, Форд Транзит, Ивеко Дейли)', is_active: true },
  { name: 'Малотоннажный грузовик', description: 'Грузовые автомобили грузоподъемностью до 3,5 тонн', is_active: true },
  { name: 'Микроавтобус', description: 'Автобус малой вместимости для перевозки до 20 пассажиров', is_active: true }
]

car_types.each do |car_type|
  CarType.find_or_create_by(name: car_type[:name]) do |ct|
    ct.description = car_type[:description]
    ct.is_active = car_type[:is_active]
  end
end
