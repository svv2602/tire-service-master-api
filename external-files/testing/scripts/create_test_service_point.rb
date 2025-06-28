# Скрипт для создания тестовой сервисной точки со статусом temporarily_closed

partner = Partner.find(2)
lviv_city = City.find_by(name: 'Львів')

if lviv_city.nil?
  puts "Город Львів не найден!"
  exit 1
end

sp = partner.service_points.create!(
  name: 'АвтоШина Плюс на Сихові (Тест)',
  description: 'Тестовая точка для проверки фильтров',
  address: 'вул. Сихівська, 15',
  city_id: lviv_city.id,
  contact_phone: '+380322556677',
  is_active: true,
  work_status: 'temporarily_closed',
  working_hours: {
    'monday' => {'start' => '09:00', 'end' => '18:00', 'is_working_day' => true},
    'tuesday' => {'start' => '09:00', 'end' => '18:00', 'is_working_day' => true},
    'wednesday' => {'start' => '09:00', 'end' => '18:00', 'is_working_day' => true},
    'thursday' => {'start' => '09:00', 'end' => '18:00', 'is_working_day' => true},
    'friday' => {'start' => '09:00', 'end' => '18:00', 'is_working_day' => true},
    'saturday' => {'start' => '09:00', 'end' => '16:00', 'is_working_day' => true},
    'sunday' => {'start' => '00:00', 'end' => '00:00', 'is_working_day' => false}
  }
)

puts "Создана точка: ID=#{sp.id}, Name=#{sp.name}, Status=#{sp.work_status}, Active=#{sp.is_active}"
puts "Город: #{sp.city.name}" 