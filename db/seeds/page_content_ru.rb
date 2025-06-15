# Русский контент для главной страницы клиента
puts "Создание русского контента для главной страницы клиента..."

# Очищаем существующий русский контент
PageContent.where(section: 'client_main', language: 'ru').destroy_all

# Hero секция
PageContent.create!(
  section: 'client_main',
  content_type: 'hero',
  title: 'Найдите лучший шиномонтаж рядом с вами',
  content: 'Быстрое бронирование, проверенные мастера, гарантия качества',
  settings: {
    subtitle: 'Быстрое бронирование, проверенные мастера, гарантия качества',
    button_text: 'Найти',
    search_placeholder: 'Найти сервис или услугу',
    city_placeholder: 'Город'
  },
  position: 1,
  active: true,
  language: 'ru'
)

# Города (автоматически подтягиваются из базы)
PageContent.create!(
  section: 'client_main',
  content_type: 'city',
  title: 'Города обслуживания',
  content: 'Найдите ближайший сервис в вашем городе',
  settings: {
    type: 'cities_list'
  },
  position: 2,
  active: true,
  language: 'ru'
)

# Услуги
services_ru = [
  {
    title: 'Замена шин',
    content: 'Профессиональная замена летних и зимних шин',
    category: 'Шиномонтаж',
    icon: 'tire'
  },
  {
    title: 'Балансировка колес',
    content: 'Устранение вибрации и неравномерного износа',
    category: 'Балансировка',
    icon: 'balance'
  },
  {
    title: 'Ремонт проколов',
    content: 'Быстрый и качественный ремонт проколов',
    category: 'Ремонт',
    icon: 'repair'
  },
  {
    title: 'Шиномонтаж',
    content: 'Снятие и установка шин на диски',
    category: 'Шиномонтаж',
    icon: 'mount'
  }
]

services_ru.each_with_index do |service, index|
  PageContent.create!(
    section: 'client_main',
    content_type: 'service',
    title: service[:title],
    content: service[:content],
    settings: {
      category: service[:category],
      icon: service[:icon]
    },
    position: 3 + index,
    active: true,
    language: 'ru'
  )
end

# Статьи базы знаний (автоматически подтягиваются из базы)
PageContent.create!(
  section: 'client_main',
  content_type: 'article',
  title: 'База знаний',
  content: 'Полезные советы и рекомендации от экспертов',
  settings: {
    type: 'knowledge_base'
  },
  position: 7,
  active: true,
  language: 'ru'
)

# CTA секция
PageContent.create!(
  section: 'client_main',
  content_type: 'cta',
  title: 'Готовы записаться на сервис?',
  content: 'Выберите удобное время и ближайший сервис',
  settings: {
    primary_button_text: 'Записаться сейчас',
    secondary_button_text: 'Узнать больше'
  },
  position: 8,
  active: true,
  language: 'ru'
)

# Footer
PageContent.create!(
  section: 'client_main',
  content_type: 'footer',
  title: 'Твоя Шина',
  content: 'Лучший сервис шиномонтажа в Украине. Профессиональные мастера, современное оборудование, гарантия качества.',
  settings: {
    contact_info: {
      phone: '+380 (44) 123-45-67',
      email: 'info@tvoya-shina.ua'
    },
    social_links: {
      facebook: 'https://facebook.com/tvoya-shina',
      instagram: 'https://instagram.com/tvoya-shina',
      telegram: 'https://t.me/tvoya-shina'
    },
    services_links: ['Замена шин', 'Балансировка', 'Ремонт проколов'],
    info_links: ['База знаний', 'Личный кабинет', 'Для бизнеса'],
    copyright: '© 2024 Твоя Шина. Все права защищены.'
  },
  position: 9,
  active: true,
  language: 'ru'
)

puts "Русский контент создан успешно!"
puts "Создано #{PageContent.where(section: 'client_main', language: 'ru').count} элементов контента" 