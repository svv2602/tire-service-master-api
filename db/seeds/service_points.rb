# db/seeds/service_points.rb
# Створення тестових даних для точок обслуговування

puts 'Creating service points...'

# Очищення існуючих записів
ServicePoint.destroy_all

# Визначення статусів сервісних точок
STATUSES = {
  active: 1,
  suspended: 2,
  blocked: 3
}

# Дані міст
cities = [
  { id: 1, name: 'Київ' },
  { id: 2, name: 'Львів' },
  { id: 3, name: 'Одеса' },
  { id: 4, name: 'Харків' },
  { id: 5, name: 'Дніпро' },
  { id: 6, name: 'Запоріжжя' },
  { id: 7, name: 'Вінниця' },
  { id: 8, name: 'Івано-Франківськ' },
  { id: 9, name: 'Тернопіль' },
  { id: 10, name: 'Житомир' }
]

# Створення або оновлення міст
cities.each do |city_data|
  city = City.find_or_initialize_by(id: city_data[:id])
  city.update!(name: city_data[:name])
end

puts "  Created #{cities.count} cities"

# Отримання всіх партнерів
partners = Partner.all

if partners.empty?
  puts "  No partners found, please run partners seed first"
else
  # Дані сервісних точок
  service_points_data = [
    {
      partner_id: partners[0].id,
      name: 'ШиноСервіс Експрес на Хрещатику',
      description: 'Повний спектр послуг з шиномонтажу та балансування коліс',
      city_id: 1, # Київ
      address: 'вул. Хрещатик, 22',
      contact_phone: '+380 67 123 45 67',
      status_id: STATUSES[:active],
      post_count: 4,
      default_slot_duration: 30,
      latitude: 50.450001,
      longitude: 30.523333,
      rating: 4.7
    },
    {
      partner_id: partners[0].id,
      name: 'ШиноСервіс Експрес на Оболоні',
      description: 'Швидкий та якісний шиномонтаж для легкових автомобілів',
      city_id: 1, # Київ
      address: 'пр. Оболонський, 45',
      contact_phone: '+380 67 123 45 68',
      status_id: STATUSES[:active],
      post_count: 3,
      default_slot_duration: 30,
      latitude: 50.501747,
      longitude: 30.497137,
      rating: 4.5
    },
    {
      partner_id: partners[1].id,
      name: 'АвтоШина Плюс центр',
      description: 'Професійний шиномонтаж та зберігання шин',
      city_id: 2, # Львів
      address: 'вул. Личаківська, 45',
      contact_phone: '+380 50 987 65 43',
      status_id: STATUSES[:active],
      post_count: 5,
      default_slot_duration: 45,
      latitude: 49.842957,
      longitude: 24.031111,
      rating: 4.9
    },
    {
      partner_id: partners[1].id,
      name: 'АвтоШина Плюс на Сихові',
      description: 'Шиномонтаж та ремонт дисків',
      city_id: 2, # Львів
      address: 'пр. Червоної Калини, 35',
      contact_phone: '+380 50 987 65 44',
      status_id: STATUSES[:suspended],
      post_count: 2,
      default_slot_duration: 30,
      latitude: 49.816721,
      longitude: 24.056284,
      rating: 4.2
    },
    {
      partner_id: partners[2].id,
      name: 'ШинМайстер Одеса',
      description: 'Найкращі послуги шиномонтажу в місті',
      city_id: 3, # Одеса
      address: 'вул. Дерибасівська, 12',
      contact_phone: '+380 63 555 55 55',
      status_id: STATUSES[:active],
      post_count: 4,
      default_slot_duration: 40,
      latitude: 46.482526,
      longitude: 30.723309,
      rating: 4.6
    },
    {
      partner_id: partners[3].id,
      name: 'ВелоШина Харків',
      description: 'Спеціалізований шиномонтаж для велосипедів та мототехніки',
      city_id: 4, # Харків
      address: 'вул. Сумська, 37',
      contact_phone: '+380 96 111 22 33',
      status_id: STATUSES[:suspended],
      post_count: 2,
      default_slot_duration: 20,
      latitude: 49.994507,
      longitude: 36.231572,
      rating: 4.3
    },
    {
      partner_id: partners[4].id,
      name: 'МастерШина Дніпро',
      description: 'Комплексне обслуговування та ремонт шин',
      city_id: 5, # Дніпро
      address: 'пр. Яворницького, 45',
      contact_phone: '+380 73 444 33 22',
      status_id: STATUSES[:active],
      post_count: 6,
      default_slot_duration: 35,
      latitude: 48.464717,
      longitude: 35.046183,
      rating: 4.8
    },
    {
      partner_id: partners[4].id,
      name: 'МастерШина Лівобережний',
      description: 'Шиномонтаж та технічне обслуговування',
      city_id: 5, # Дніпро
      address: 'вул. Кайдацька, 122',
      contact_phone: '+380 73 444 33 23',
      status_id: STATUSES[:blocked],
      post_count: 3,
      default_slot_duration: 30,
      latitude: 48.471367,
      longitude: 35.052494,
      rating: 3.9
    }
  ]

  # Створення сервісних точок
  service_points_data.each do |point_data|
    point = ServicePoint.create!(point_data)
    puts "  Created service point: #{point.name} (Partner: #{point.partner.company_name})"
  end

  puts "Created #{ServicePoint.count} service points successfully!"
end 