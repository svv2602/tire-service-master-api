# db/seeds/partners.rb
# Створення тестових даних для партнерів

puts 'Creating partners...'

# Очищення існуючих записів
Partner.destroy_all

partners_data = [
  {
    company_name: 'ШиноСервіс Експрес',
    contact_person: 'Петренко Олександр Іванович',
    phone: '+380 67 123 45 67',
    email: 'info@shino-express.ua',
    address: 'м. Київ, вул. Хрещатик, 22',
    legal_entity: 'ТОВ "ШиноСервіс Експрес"',
    tax_id: '12345678',
    status: 'active'
  },
  {
    company_name: 'АвтоШина Плюс',
    contact_person: 'Коваленко Андрій Петрович',
    phone: '+380 50 987 65 43',
    email: 'contact@autoshina-plus.ua',
    address: 'м. Львів, вул. Личаківська, 45',
    legal_entity: 'ФОП Коваленко А.П.',
    tax_id: '87654321',
    status: 'active'
  },
  {
    company_name: 'ШинМайстер',
    contact_person: 'Савченко Ірина Олегівна',
    phone: '+380 63 555 55 55',
    email: 'info@shinmaister.ua',
    address: 'м. Одеса, вул. Дерибасівська, 12',
    legal_entity: 'ТОВ "ШинМайстер"',
    tax_id: '23456789',
    status: 'active'
  },
  {
    company_name: 'ВелоШина',
    contact_person: 'Мельник Дмитро Сергійович',
    phone: '+380 96 111 22 33',
    email: 'info@veloshina.ua',
    address: 'м. Харків, вул. Сумська, 37',
    legal_entity: 'ФОП Мельник Д.С.',
    tax_id: '34567890',
    status: 'suspended'
  },
  {
    company_name: 'МастерШина',
    contact_person: 'Шевченко Олег Вікторович',
    phone: '+380 73 444 33 22',
    email: 'master@shina-pro.ua',
    address: 'м. Дніпро, пр. Яворницького, 45',
    legal_entity: 'ТОВ "МастерШина"',
    tax_id: '45678901',
    status: 'active'
  }
]

partners_data.each do |partner_data|
  partner = Partner.create!(partner_data)
  puts "  Created partner: #{partner.company_name}"
end

puts "Created #{Partner.count} partners successfully!" 