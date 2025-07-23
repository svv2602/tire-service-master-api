# SEO Метатеги для всех страниц сайта
puts "🔍 Создание SEO метатегов..."

seo_data = [
  # Главная страница
  {
    page_type: 'home',
    language: 'uk',
    title: 'Твоя Шина - Професійний шиномонтаж в Україні',
    description: 'Професійний шиномонтаж в Україні. Заміна шин, балансування коліс, ремонт дисків. Онлайн запис, швидке обслуговування, гарантія якості.',
    keywords: 'шиномонтаж, заміна шин, балансування коліс, ремонт дисків, шиномонтаж україна',
    image_url: '/image/tire-service-og.jpg',
    canonical_url: '/',
    no_index: false
  },
  {
    page_type: 'home',
    language: 'ru',
    title: 'Твоя Шина - Профессиональный шиномонтаж в Украине',
    description: 'Профессиональный шиномонтаж в Украине. Замена шин, балансировка колес, ремонт дисков. Онлайн запись, быстрое обслуживание, гарантия качества.',
    keywords: 'шиномонтаж, замена шин, балансировка колес, ремонт дисков, шиномонтаж украина',
    image_url: '/image/tire-service-og.jpg',
    canonical_url: '/',
    no_index: false
  },

  # Страница услуг
  {
    page_type: 'services',
    language: 'uk',
    title: 'Послуги шиномонтажу - Твоя Шина',
    description: 'Повний спектр послуг шиномонтажу: заміна шин, балансування, ремонт дисків, зберігання коліс. Професійне обладнання та досвідчені майстри.',
    keywords: 'послуги шиномонтажу, заміна шин, балансування, ремонт дисків, зберігання коліс',
    image_url: '/image/services-og.jpg',
    canonical_url: 'https://tvoya-shina.ua/client/services',
    no_index: false
  },
  {
    page_type: 'services',
    language: 'ru',
    title: 'Услуги шиномонтажа - Твоя Шина',
    description: 'Полный спектр услуг шиномонтажа: замена шин, балансировка, ремонт дисков, хранение колес. Профессиональное оборудование и опытные мастера.',
    keywords: 'услуги шиномонтажа, замена шин, балансировка, ремонт дисков, хранение колес',
    image_url: '/image/services-og.jpg',
    canonical_url: 'https://tvoya-shina.ua/client/services',
    no_index: false
  },

  # Поиск сервисов
  {
    page_type: 'search',
    language: 'uk',
    title: 'Пошук сервісних центрів - Твоя Шина',
    description: 'Знайдіть найближчий сервісний центр шиномонтажу. Пошук за містом, послугами, рейтингом. Онлайн запис та відгуки клієнтів.',
    keywords: 'пошук шиномонтажу, сервісні центри, шиномонтаж поблизу, відгуки клієнтів',
    image_url: '/image/search-og.jpg',
    canonical_url: 'https://tvoya-shina.ua/client/search',
    no_index: false
  },
  {
    page_type: 'search',
    language: 'ru',
    title: 'Поиск сервисных центров - Твоя Шина',
    description: 'Найдите ближайший сервисный центр шиномонтажа. Поиск по городу, услугам, рейтингу. Онлайн запись и отзывы клиентов.',
    keywords: 'поиск шиномонтажа, сервисные центры, шиномонтаж рядом, отзывы клиентов',
    image_url: '/image/search-og.jpg',
    canonical_url: 'https://tvoya-shina.ua/client/search',
    no_index: false
  },

  # Онлайн запись
  {
    page_type: 'booking',
    language: 'uk',
    title: 'Онлайн запис на шиномонтаж - Твоя Шина',
    description: 'Зручний онлайн запис на шиномонтаж. Оберіть час, послугу та сервісний центр. Миттєве підтвердження запису та нагадування.',
    keywords: 'онлайн запис, запис на шиномонтаж, бронювання послуг, швидкий запис',
    image_url: '/image/booking-og.jpg',
    canonical_url: 'https://tvoya-shina.ua/client/booking',
    no_index: false
  },
  {
    page_type: 'booking',
    language: 'ru',
    title: 'Онлайн запись на шиномонтаж - Твоя Шина',
    description: 'Удобная онлайн запись на шиномонтаж. Выберите время, услугу и сервисный центр. Мгновенное подтверждение записи и напоминания.',
    keywords: 'онлайн запись, запись на шиномонтаж, бронирование услуг, быстрая запись',
    image_url: '/image/booking-og.jpg',
    canonical_url: 'https://tvoya-shina.ua/client/booking',
    no_index: false
  },

  # Калькулятор шин
  {
    page_type: 'calculator',
    language: 'uk',
    title: 'Калькулятор шин - підбір розміру - Твоя Шина',
    description: 'Безкоштовний калькулятор підбору шин. Визначте оптимальний розмір шин для вашого автомобіля за маркою та моделлю.',
    keywords: 'калькулятор шин, підбір шин, розмір шин, шини за маркою авто',
    image_url: '/image/calculator-og.jpg',
    canonical_url: 'https://tvoya-shina.ua/client/tire-calculator',
    no_index: false
  },
  {
    page_type: 'calculator',
    language: 'ru',
    title: 'Калькулятор шин - подбор размера - Твоя Шина',
    description: 'Бесплатный калькулятор подбора шин. Определите оптимальный размер шин для вашего автомобиля по марке и модели.',
    keywords: 'калькулятор шин, подбор шин, размер шин, шины по марке авто',
    image_url: '/image/calculator-og.jpg',
    canonical_url: 'https://tvoya-shina.ua/client/tire-calculator',
    no_index: false
  },

  # База знаний
  {
    page_type: 'knowledge-base',
    language: 'uk',
    title: 'База знань про шини та диски - Твоя Шина',
    description: 'Корисні статті про шини, диски, експлуатацію та догляд. Поради експертів, інструкції та рекомендації для автовласників.',
    keywords: 'база знань, статті про шини, поради експертів, догляд за шинами',
    image_url: '/image/knowledge-base-og.jpg',
    canonical_url: 'https://tvoya-shina.ua/knowledge-base',
    no_index: false
  },
  {
    page_type: 'knowledge-base',
    language: 'ru',
    title: 'База знаний о шинах и дисках - Твоя Шина',
    description: 'Полезные статьи о шинах, дисках, эксплуатации и уходе. Советы экспертов, инструкции и рекомендации для автовладельцев.',
    keywords: 'база знаний, статьи о шинах, советы экспертов, уход за шинами',
    image_url: '/image/knowledge-base-og.jpg',
    canonical_url: 'https://tvoya-shina.ua/knowledge-base',
    no_index: false
  },

  # Статьи
  {
    page_type: 'article',
    language: 'uk',
    title: 'Стаття - Твоя Шина',
    description: 'Експертна стаття про шини, диски та автосервіс. Корисні поради та рекомендації від професіоналів шиномонтажу.',
    keywords: 'стаття про шини, поради експертів, шиномонтаж, автосервіс',
    image_url: '/image/article-og.jpg',
    canonical_url: 'https://tvoya-shina.ua/knowledge-base/articles',
    no_index: false
  },
  {
    page_type: 'article',
    language: 'ru',
    title: 'Статья - Твоя Шина',
    description: 'Экспертная статья о шинах, дисках и автосервисе. Полезные советы и рекомендации от профессионалов шиномонтажа.',
    keywords: 'статья о шинах, советы экспертов, шиномонтаж, автосервис',
    image_url: '/image/article-og.jpg',
    canonical_url: 'https://tvoya-shina.ua/knowledge-base/articles',
    no_index: false
  },

  # Сервисные точки
  {
    page_type: 'service-point',
    language: 'uk',
    title: 'Сервісний центр - Твоя Шина',
    description: 'Інформація про сервісний центр шиномонтажу: послуги, розклад роботи, контакти, відгуки клієнтів та онлайн запис.',
    keywords: 'сервісний центр, шиномонтаж, послуги, відгуки, онлайн запис',
    image_url: '/image/service-point-og.jpg',
    canonical_url: 'https://tvoya-shina.ua/client/search',
    no_index: false
  },
  {
    page_type: 'service-point',
    language: 'ru',
    title: 'Сервисный центр - Твоя Шина',
    description: 'Информация о сервисном центре шиномонтажа: услуги, расписание работы, контакты, отзывы клиентов и онлайн запись.',
    keywords: 'сервисный центр, шиномонтаж, услуги, отзывы, онлайн запись',
    image_url: '/image/service-point-og.jpg',
    canonical_url: 'https://tvoya-shina.ua/client/search',
    no_index: false
  },

  # Личный кабинет (приватная страница)
  {
    page_type: 'profile',
    language: 'uk',
    title: 'Особистий кабінет - Твоя Шина',
    description: 'Особистий кабінет клієнта. Управління записами, історія послуг, налаштування профілю та сповіщень.',
    keywords: 'особистий кабінет, профіль клієнта, мої записи',
    image_url: '/image/profile-og.jpg',
    canonical_url: 'https://tvoya-shina.ua/profile',
    no_index: true
  },
  {
    page_type: 'profile',
    language: 'ru',
    title: 'Личный кабинет - Твоя Шина',
    description: 'Личный кабинет клиента. Управление записями, история услуг, настройки профиля и уведомлений.',
    keywords: 'личный кабинет, профиль клиента, мои записи',
    image_url: '/image/profile-og.jpg',
    canonical_url: 'https://tvoya-shina.ua/profile',
    no_index: true
  },

  # Админ панель (приватная страница)
  {
    page_type: 'admin',
    language: 'uk',
    title: 'Адміністративна панель - Твоя Шина',
    description: 'Панель управління системою шиномонтажу для адміністраторів.',
    keywords: 'адмін панель, управління системою',
    image_url: '/image/admin-og.jpg',
    canonical_url: 'https://tvoya-shina.ua/admin',
    no_index: true
  },
  {
    page_type: 'admin',
    language: 'ru',
    title: 'Административная панель - Твоя Шина',
    description: 'Панель управления системой шиномонтажа для администраторов.',
    keywords: 'админ панель, управление системой',
    image_url: '/image/admin-og.jpg',
    canonical_url: 'https://tvoya-shina.ua/admin',
    no_index: true
  },

  # Вход в систему (приватная страница)
  {
    page_type: 'login',
    language: 'uk',
    title: 'Вхід в систему - Твоя Шина',
    description: 'Увійдіть в особистий кабінет для управління записами та налаштуваннями.',
    keywords: 'вхід, авторизація, особистий кабінет',
    image_url: '/image/login-og.jpg',
    canonical_url: 'https://tvoya-shina.ua/login',
    no_index: true
  },
  {
    page_type: 'login',
    language: 'ru',
    title: 'Вход в систему - Твоя Шина',
    description: 'Войдите в личный кабинет для управления записями и настройками.',
    keywords: 'вход, авторизация, личный кабинет',
    image_url: '/image/login-og.jpg',
    canonical_url: 'https://tvoya-shina.ua/login',
    no_index: true
  },

  # Регистрация (приватная страница)
  {
    page_type: 'register',
    language: 'uk',
    title: 'Реєстрація - Твоя Шина',
    description: 'Створіть особистий кабінет для зручного онлайн запису на шиномонтаж.',
    keywords: 'реєстрація, створити акаунт, особистий кабінет',
    image_url: '/image/register-og.jpg',
    canonical_url: 'https://tvoya-shina.ua/register',
    no_index: true
  },
  {
    page_type: 'register',
    language: 'ru',
    title: 'Регистрация - Твоя Шина',
    description: 'Создайте личный кабинет для удобной онлайн записи на шиномонтаж.',
    keywords: 'регистрация, создать аккаунт, личный кабинет',
    image_url: '/image/register-og.jpg',
    canonical_url: 'https://tvoya-shina.ua/register',
    no_index: true
  }
]

# Создание или обновление SEO метатегов
created_count = 0
updated_count = 0

seo_data.each do |data|
  seo_metatag = SeoMetatag.find_by(page_type: data[:page_type], language: data[:language])
  
  if seo_metatag
    seo_metatag.update!(data)
    updated_count += 1
    puts "  ✅ Обновлен: #{data[:page_type]} (#{data[:language]})"
  else
    SeoMetatag.create!(data)
    created_count += 1
    puts "  ➕ Создан: #{data[:page_type]} (#{data[:language]})"
  end
end

puts "\n🎉 SEO метатеги успешно загружены!"
puts "   📊 Создано: #{created_count}"
puts "   🔄 Обновлено: #{updated_count}"
puts "   📈 Всего: #{SeoMetatag.count}"

# Проверяем статус SEO оптимизации
good_count = SeoMetatag.select { |m| m.seo_status == 'good' }.count
warning_count = SeoMetatag.select { |m| m.seo_status == 'warning' }.count
error_count = SeoMetatag.select { |m| m.seo_status == 'error' }.count

puts "\n📈 Статистика SEO оптимизации:"
puts "   ✅ Хорошо: #{good_count}"
puts "   ⚠️  Внимание: #{warning_count}"
puts "   ❌ Ошибки: #{error_count}" 