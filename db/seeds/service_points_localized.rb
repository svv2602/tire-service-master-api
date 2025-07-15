# Локализация существующих сервисных точек
puts "=== Обновление локализованных полей сервисных точек ==="

# Локализованные данные для сервисных точек
localized_data = {
  'ШиноСервіс Експрес на Хрещатику' => {
    name_ru: 'ШиноСервис Экспресс на Крещатике',
    name_uk: 'ШиноСервіс Експрес на Хрещатику',
    description_ru: 'Быстрый и качественный шиномонтаж в центре Киева',
    description_uk: 'Швидкий та якісний шиномонтаж у центрі Києва',
    address_ru: 'ул. Крещатик, 22',
    address_uk: 'вул. Хрещатик, 22'
  },
  'ШиноСервіс Експрес на Оболоні' => {
    name_ru: 'ШиноСервис Экспресс на Оболони',
    name_uk: 'ШиноСервіс Експрес на Оболоні',
    description_ru: 'Профессиональный шиномонтаж на Оболони',
    description_uk: 'Професійний шиномонтаж на Оболоні',
    address_ru: 'ул. Оболонская, 15',
    address_uk: 'вул. Оболонська, 15'
  },
  'АвтоШина Плюс на Позняках' => {
    name_ru: 'АвтоШина Плюс на Позняках',
    name_uk: 'АвтоШина Плюс на Позняках',
    description_ru: 'Комплексное обслуживание автомобилей на Позняках',
    description_uk: 'Комплексне обслуговування автомобілів на Позняках',
    address_ru: 'ул. Позняковская, 8',
    address_uk: 'вул. Позняківська, 8'
  },
  'АвтоШина Плюс центр' => {
    name_ru: 'АвтоШина Плюс центр',
    name_uk: 'АвтоШина Плюс центр',
    description_ru: 'Центральный офис АвтоШина Плюс',
    description_uk: 'Центральний офіс АвтоШина Плюс',
    address_ru: 'ул. Центральная, 45',
    address_uk: 'вул. Центральна, 45'
  },
  'КолесоМайстер Львів' => {
    name_ru: 'КолесоМастер Львов',
    name_uk: 'КолесоМайстер Львів',
    description_ru: 'Мастерская по ремонту колес во Львове',
    description_uk: 'Майстерня з ремонту коліс у Львові',
    address_ru: 'ул. Львовская, 12',
    address_uk: 'вул. Львівська, 12'
  },
  'КолесоМайстер Одеса' => {
    name_ru: 'КолесоМастер Одесса',
    name_uk: 'КолесоМайстер Одеса',
    description_ru: 'Профессиональный шиномонтаж в Одессе',
    description_uk: 'Професійний шиномонтаж в Одесі',
    address_ru: 'ул. Одесская, 33',
    address_uk: 'вул. Одеська, 33'
  },
  'ШвидкоШина Одеса' => {
    name_ru: 'БыстроШина Одесса',
    name_uk: 'ШвидкоШина Одеса',
    description_ru: 'Быстрый шиномонтаж в Одессе',
    description_uk: 'Швидкий шиномонтаж в Одесі',
    address_ru: 'ул. Быстрая, 7',
    address_uk: 'вул. Швидка, 7'
  },
  'ШвидкоШина Харків' => {
    name_ru: 'БыстроШина Харьков',
    name_uk: 'ШвидкоШина Харків',
    description_ru: 'Скоростной шиномонтаж в Харькове',
    description_uk: 'Швидкісний шиномонтаж у Харкові',
    address_ru: 'ул. Харьковская, 25',
    address_uk: 'вул. Харківська, 25'
  }
}

updated_count = 0
ServicePoint.all.each do |service_point|
  data = localized_data[service_point.name]
  
  if data
    service_point.update!(
      name_ru: data[:name_ru],
      name_uk: data[:name_uk],
      description_ru: data[:description_ru],
      description_uk: data[:description_uk],
      address_ru: data[:address_ru],
      address_uk: data[:address_uk]
    )
    puts "  ✅ Обновлена точка: #{service_point.name}"
    updated_count += 1
  else
    puts "  ⚠️  Не найдены данные для: #{service_point.name}"
  end
end

puts "\n📊 Результат:"
puts "  Обновлено сервисных точек: #{updated_count}"
puts "  Всего сервисных точек: #{ServicePoint.count}"
puts "✅ Локализация сервисных точек завершена!" 