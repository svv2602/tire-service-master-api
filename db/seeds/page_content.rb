puts 'Создание украинского контента...'

# Сиды для контента главной страницы клиента (украинская локализация)

puts "🌟 Создание контента главной страницы клиента..."

# Очищаем существующий контент
PageContent.where(section: 'client_main').destroy_all

# Hero секция
hero_content = PageContent.create!(
  section: 'client_main',
  content_type: 'hero',
  title: 'Знайдіть найкращий автосервис поруч з вами',
  content: 'Швидке бронювання, перевірені майстри, гарантія якості',
  position: 1,
  active: true,
  settings: {
    subtitle: 'Швидке бронювання, перевірені майстри, гарантія якості',
    button_text: 'Знайти',
    search_placeholder: 'Знайти сервіс або послугу',
    city_placeholder: 'Місто'
  }
)

# Украинские города
cities_content = PageContent.create!(
  section: 'client_main',
  content_type: 'text_block',
  title: 'Українські міста',
  content: 'Київ,Харків,Одеса,Дніпро,Запоріжжя,Львів,Кривий Ріг,Миколаїв',
  position: 2,
  active: true,
  settings: {
    type: 'cities_list'
  }
)

# Популярные услуги
services = [
  {
    title: 'Заміна шин',
    price: 'від 150 ₴',
    duration: '30 хв',
    description: 'Професійна заміна літніх та зимових шин',
    icon: 'tire'
  },
  {
    title: 'Балансування коліс',
    price: 'від 80 ₴',
    duration: '15 хв',
    description: 'Усунення вібрації та нерівномірного зносу',
    icon: 'balance'
  },
  {
    title: 'Ремонт проколів',
    price: 'від 100 ₴',
    duration: '20 хв',
    description: 'Швидкий та якісний ремонт проколів',
    icon: 'repair'
  },
  {
    title: 'Шиномонтаж',
    price: 'від 120 ₴',
    duration: '25 хв',
    description: 'Зняття та встановлення шин на диски',
    icon: 'mount'
  }
]

services.each_with_index do |service, index|
  PageContent.create!(
    section: 'client_main',
    content_type: 'service',
    title: service[:title],
    content: service[:description],
    position: 10 + index,
    active: true,
    settings: {
      price: service[:price],
      duration: service[:duration],
      icon: service[:icon]
    }
  )
end

# Статьи базы знаний
articles = [
  {
    title: 'Як вибрати зимові шини',
    excerpt: 'Детальний посібник з вибору зимових шин для безпечної їзди',
    read_time: '5 хв',
    author: 'Експерт з шин'
  },
  {
    title: 'Правильний тиск у шинах',
    excerpt: 'Вплив тиску на безпеку та витрату палива',
    read_time: '3 хв',
    author: 'Технічний спеціаліст'
  },
  {
    title: 'Сезонне зберігання шин',
    excerpt: 'Як правильно зберігати шини в міжсезоння',
    read_time: '4 хв',
    author: 'Майстер сервісу'
  }
]

articles.each_with_index do |article, index|
  PageContent.create!(
    section: 'client_main',
    content_type: 'article',
    title: article[:title],
    content: article[:excerpt],
    position: 30 + index,
    active: true,
    settings: {
      read_time: article[:read_time],
      author: article[:author]
    }
  )
end

# CTA секция
cta_content = PageContent.create!(
  section: 'client_main',
  content_type: 'cta',
  title: 'Готові записатися на обслуговування?',
  content: 'Оберіть зручний час та найближчий сервіс',
  position: 40,
  active: true,
  settings: {
    primary_button_text: 'Записатися онлайн',
    secondary_button_text: 'Особистий кабінет'
  }
)

# Футер
footer_content = PageContent.create!(
  section: 'client_main',
  content_type: 'text_block',
  title: '🚗 Твоя Шина',
  content: 'Знайдіть найкращий автосервис поруч з вами. Швидке бронювання, перевірені майстри.',
  position: 50,
  active: true,
  settings: {
    type: 'footer',
    copyright: '© 2024 Твоя Шина. Всі права захищені.',
    services_links: ['Заміна шин', 'Балансування', 'Ремонт проколів'],
    info_links: ['База знань', 'Особистий кабінет', 'Для бізнесу']
  }
)

puts "✅ Створено #{PageContent.where(section: 'client_main').count} елементів контенту для головної сторінки"
puts "🇺🇦 Всі російські терміни замінено на українські"
