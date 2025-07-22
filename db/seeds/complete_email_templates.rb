# Полный seed для email шаблонов на украинском и русском языках
# Удаляем существующие шаблоны и создаем заново

puts "🗑️ Удаляем существующие email шаблоны..."
EmailTemplate.destroy_all
EmailTemplateCustomVariable.destroy_all

puts "📧 Создаем email шаблоны..."

# Массив шаблонов для создания
templates_data = [
  # 1. ПОДТВЕРЖДЕНИЕ БРОНИРОВАНИЯ
  {
    name: 'Підтвердження бронювання',
    template_type: 'booking_confirmation',
    language: 'uk',
    subject: 'Підтверджено: бронювання #{booking_id} на {booking_date}',
    body: %{
Вітаємо, {client_name}!

✅ ВАШЕ БРОНЮВАННЯ ПІДТВЕРДЖЕНО:

📅 ДЕТАЛІ ЗАПИСУ:
• Номер бронювання: {booking_id}
• Дата: {booking_date}
• Час: {start_time}
• Сервісна точка: {service_point_name}
• Адреса: {service_point_address}
• Телефон: {service_point_phone}
• Місто: {city_name}

🚗 АВТОМОБІЛЬ:
{car_brand} {car_model}
Номер: {license_plate}

{current_promotion}

📞 КОНТАКТИ:
• Сервісна точка: {service_point_phone}
• Підтримка: {support_phone}
• Email: {support_email}

{emergency_contact}

З повагою,
Команда {company_name}
🌐 {website_url}
    }.strip,
    is_active: true
  },
  {
    name: 'Подтверждение бронирования',
    template_type: 'booking_confirmation',
    language: 'ru',
    subject: 'Подтверждено: бронирование #{booking_id} на {booking_date}',
    body: %{
Здравствуйте, {client_name}!

✅ ВАШЕ БРОНИРОВАНИЕ ПОДТВЕРЖДЕНО:

📅 ДЕТАЛИ ЗАПИСИ:
• Номер бронирования: {booking_id}
• Дата: {booking_date}
• Время: {start_time}
• Сервисная точка: {service_point_name}
• Адрес: {service_point_address}
• Телефон: {service_point_phone}
• Город: {city_name}

🚗 АВТОМОБИЛЬ:
{car_brand} {car_model}
Номер: {license_plate}

{current_promotion}

📞 КОНТАКТЫ:
• Сервисная точка: {service_point_phone}
• Поддержка: {support_phone}
• Email: {support_email}

{emergency_contact}

С уважением,
Команда {company_name}
🌐 {website_url}
    }.strip,
    is_active: true
  },

  # 2. НАПОМИНАНИЕ О ЗАПИСИ
  {
    name: 'Нагадування про запис',
    template_type: 'booking_reminder',
    language: 'uk',
    subject: 'Нагадування: ваш запис завтра о {start_time}',
    body: %{
Доброго дня, {client_name}!

⏰ НАГАДУЄМО ПРО ВАШ ЗАПИС:

📅 ЗАВТРА, {booking_date} о {start_time}
🏢 {service_point_name}
📍 {service_point_address}
🚗 Автомобіль: {car_brand} {car_model} ({license_plate})

📞 Якщо потрібно перенести запис: {service_point_phone}

{weather_warning}
{seasonal_recommendation}
{emergency_contact}

До зустрічі!
Команда {company_name}
    }.strip,
    is_active: true
  },
  {
    name: 'Напоминание о записи',
    template_type: 'booking_reminder',
    language: 'ru',
    subject: 'Напоминание: ваша запись завтра в {start_time}',
    body: %{
Добрый день, {client_name}!

⏰ НАПОМИНАЕМ О ВАШЕЙ ЗАПИСИ:

📅 ЗАВТРА, {booking_date} в {start_time}
🏢 {service_point_name}
📍 {service_point_address}
🚗 Автомобиль: {car_brand} {car_model} ({license_plate})

📞 Если нужно перенести запись: {service_point_phone}

{weather_warning}
{seasonal_recommendation}
{emergency_contact}

До встречи!
Команда {company_name}
    }.strip,
    is_active: true
  },

  # 3. ОТМЕНА БРОНИРОВАНИЯ
  {
    name: 'Скасування бронювання',
    template_type: 'booking_cancelled',
    language: 'uk',
    subject: 'Бронювання скасовано - {booking_id}',
    body: %{
{client_name}, повідомляємо про скасування.

❌ СКАСОВАНЕ БРОНЮВАННЯ:
• Номер: {booking_id}
• Дата: {booking_date}
• Час: {start_time}
• Сервісна точка: {service_point_name}

Ви можете створити нове бронювання на сайті {website_url}

{current_promotion}

📞 Контакти для нового запису:
• {service_point_phone} - {service_point_name}
• {support_phone} - загальна підтримка

{emergency_contact}

З повагою,
Команда {company_name}
    }.strip,
    is_active: true
  },
  {
    name: 'Отмена бронирования',
    template_type: 'booking_cancelled',
    language: 'ru',
    subject: 'Бронирование отменено - {booking_id}',
    body: %{
{client_name}, уведомляем об отмене.

❌ ОТМЕНЕННОЕ БРОНИРОВАНИЕ:
• Номер: {booking_id}
• Дата: {booking_date}
• Время: {start_time}
• Сервисная точка: {service_point_name}

Вы можете создать новое бронирование на сайте {website_url}

{current_promotion}

📞 Контакты для новой записи:
• {service_point_phone} - {service_point_name}
• {support_phone} - общая поддержка

{emergency_contact}

С уважением,
Команда {company_name}
    }.strip,
    is_active: true
  },

  # 4. ЗАВЕРШЕНИЕ ОБСЛУЖИВАНИЯ
  {
    name: 'Завершення обслуговування',
    template_type: 'service_completed',
    language: 'uk',
    subject: 'Обслуговування завершено - {booking_id}',
    body: %{
Вітаємо, {client_name}!

✅ ВАШЕ ОБСЛУГОВУВАННЯ ЗАВЕРШЕНО:

📅 Дата: {booking_date} о {start_time}
🏢 {service_point_name}
🚗 Автомобіль: {car_brand} {car_model} ({license_plate})

{current_promotion}
{loyalty_bonus}

Дякуємо за довіру!
Команда {company_name}
📧 {support_email}
    }.strip,
    is_active: true
  },
  {
    name: 'Завершение обслуживания',
    template_type: 'service_completed',
    language: 'ru',
    subject: 'Обслуживание завершено - {booking_id}',
    body: %{
Здравствуйте, {client_name}!

✅ ВАШЕ ОБСЛУЖИВАНИЕ ЗАВЕРШЕНО:

📅 Дата: {booking_date} в {start_time}
🏢 {service_point_name}
🚗 Автомобиль: {car_brand} {car_model} ({license_plate})

{current_promotion}
{loyalty_bonus}

Спасибо за доверие!
Команда {company_name}
📧 {support_email}
    }.strip,
    is_active: true
  },

  # 5. ЗАПРОС ОТЗЫВА
  {
    name: 'Запит відгуку',
    template_type: 'review_request',
    language: 'uk',
    subject: 'Поділіться враженнями про обслуговування',
    body: %{
Вітаємо, {client_name}!

Дякуємо за відвідування {service_point_name}!

⭐ ПОДІЛІТЬСЯ ВРАЖЕННЯМИ:
Ваша думка допоможе нам стати кращими.

📅 Ваш візит: {booking_date} о {start_time}
🚗 Автомобіль: {car_brand} {car_model}

Залиште відгук на сайті: {website_url}

{current_promotion}
{loyalty_bonus}

Дякуємо за довіру!
Команда {company_name}
📧 {support_email}
    }.strip,
    is_active: true
  },
  {
    name: 'Запрос отзыва',
    template_type: 'review_request',
    language: 'ru',
    subject: 'Поделитесь впечатлениями об обслуживании',
    body: %{
Здравствуйте, {client_name}!

Спасибо за посещение {service_point_name}!

⭐ ПОДЕЛИТЕСЬ ВПЕЧАТЛЕНИЯМИ:
Ваше мнение поможет нам стать лучше.

📅 Ваш визит: {booking_date} в {start_time}
🚗 Автомобиль: {car_brand} {car_model}

Оставьте отзыв на сайте: {website_url}

{current_promotion}
{loyalty_bonus}

Спасибо за доверие!
Команда {company_name}
📧 {support_email}
    }.strip,
    is_active: true
  },

  # 6. ПРИВЕТСТВИЕ ПОЛЬЗОВАТЕЛЯ
  {
    name: 'Вітання нового користувача',
    template_type: 'user_welcome',
    language: 'uk',
    subject: 'Ласкаво просимо до {company_name}!',
    body: %{
Вітаємо, {client_name}!

🎉 ДЯКУЄМО ЗА РЕЄСТРАЦІЮ В {company_name}!

🏢 ТЕПЕР ВИ МАЄТЕ ДОСТУП ДО:
• Онлайн бронювання послуг
• Історії ваших візитів
• Персональних знижок і акцій
• Нагадувань про техогляд

🔧 НАШІ ПОСЛУГИ:
• Шиномонтаж та балансування
• Діагностика автомобіля
• Заміна масла та фільтрів
• Ремонт підвіски

{current_promotion}

📱 КОРИСНІ ПОСИЛАННЯ:
• Сайт: {website_url}
• Підтримка: {support_email}
• Телефон: {support_phone}

{additional_services}

З повагою,
Команда {company_name}
    }.strip,
    is_active: true
  },
  {
    name: 'Приветствие нового пользователя',
    template_type: 'user_welcome',
    language: 'ru',
    subject: 'Добро пожаловать в {company_name}!',
    body: %{
Здравствуйте, {client_name}!

🎉 СПАСИБО ЗА РЕГИСТРАЦИЮ В {company_name}!

🏢 ТЕПЕРЬ У ВАС ЕСТЬ ДОСТУП К:
• Онлайн бронированию услуг
• Истории ваших визитов
• Персональным скидкам и акциям
• Напоминаниям о техосмотре

🔧 НАШИ УСЛУГИ:
• Шиномонтаж и балансировка
• Диагностика автомобиля
• Замена масла и фильтров
• Ремонт подвески

{current_promotion}

📱 ПОЛЕЗНЫЕ ССЫЛКИ:
• Сайт: {website_url}
• Поддержка: {support_email}
• Телефон: {support_phone}

{additional_services}

С уважением,
Команда {company_name}
    }.strip,
    is_active: true
  },

  # 7. СБРОС ПАРОЛЯ (КЛЮЧЕВОЙ ШАБЛОН!)
  {
    name: 'Скидання пароля',
    template_type: 'password_reset',
    language: 'uk',
    subject: 'Скидання пароля - {company_name}',
    body: %{
Вітаємо, {client_name}!

Ви запросили скидання пароля для вашого облікового запису.

🔐 ДЛЯ СКИДАННЯ ПАРОЛЯ:
Перейдіть за посиланням нижче та створіть новий пароль:

{reset_url}

⚠️ БЕЗПЕКА:
• Посилання дійсне протягом 2 годин
• Якщо ви не запитували скидання, проігноруйте цей лист
• Не передавайте це посилання іншим особам

📞 ПОТРІБНА ДОПОМОГА?
Зв'яжіться з нашою службою підтримки:
• Email: {support_email}
• Телефон: {support_phone}

{emergency_contact}

З повагою,
Команда {company_name}
🌐 {website_url}
    }.strip,
    is_active: true
  },
  {
    name: 'Сброс пароля',
    template_type: 'password_reset',
    language: 'ru',
    subject: 'Сброс пароля - {company_name}',
    body: %{
Здравствуйте, {client_name}!

Вы запросили сброс пароля для вашей учетной записи.

🔐 ДЛЯ СБРОСА ПАРОЛЯ:
Перейдите по ссылке ниже и создайте новый пароль:

{reset_url}

⚠️ БЕЗОПАСНОСТЬ:
• Ссылка действительна в течение 2 часов
• Если вы не запрашивали сброс, игнорируйте это письмо
• Не передавайте эту ссылку другим лицам

📞 НУЖНА ПОМОЩЬ?
Свяжитесь с нашей службой поддержки:
• Email: {support_email}
• Телефон: {support_phone}

{emergency_contact}

С уважением,
Команда {company_name}
🌐 {website_url}
    }.strip,
    is_active: true
  },

  # 8. ИНФОРМАЦИОННАЯ РАССЫЛКА
  {
    name: 'Інформаційна розсилка',
    template_type: 'newsletter',
    language: 'uk',
    subject: 'Новини від {company_name}',
    body: %{
Вітаємо, {client_name}!

📰 НОВИНИ ТА АКЦІЇ ВІД {company_name}:

{newsletter_content}

{current_promotion}

{seasonal_recommendation}

{additional_services}

📞 КОНТАКТИ:
• Сайт: {website_url}
• Email: {support_email}
• Телефон: {support_phone}

{emergency_contact}

З повагою,
Команда {company_name}
    }.strip,
    is_active: true
  },
  {
    name: 'Информационная рассылка',
    template_type: 'newsletter',
    language: 'ru',
    subject: 'Новости от {company_name}',
    body: %{
Здравствуйте, {client_name}!

📰 НОВОСТИ И АКЦИИ ОТ {company_name}:

{newsletter_content}

{current_promotion}

{seasonal_recommendation}

{additional_services}

📞 КОНТАКТЫ:
• Сайт: {website_url}
• Email: {support_email}
• Телефон: {support_phone}

{emergency_contact}

С уважением,
Команда {company_name}
    }.strip,
    is_active: true
  }
]

# Создаем шаблоны
templates_data.each_with_index do |template_data, index|
  template = EmailTemplate.create!(template_data)
  puts "✅ #{index + 1}. Создан шаблон: #{template.name} (#{template.language})"
end

puts ""
puts "🎉 Создано #{EmailTemplate.count} email шаблонов!"
puts "🇺🇦 Украинских: #{EmailTemplate.where(language: 'uk').count}"
puts "🇷🇺 Русских: #{EmailTemplate.where(language: 'ru').count}"
puts ""
puts "📧 Типы шаблонов:"
EmailTemplate.distinct.pluck(:template_type).each do |type|
  uk_count = EmailTemplate.where(template_type: type, language: 'uk').count
  ru_count = EmailTemplate.where(template_type: type, language: 'ru').count
  puts "  • #{type}: UK=#{uk_count}, RU=#{ru_count}"
end
puts ""
puts "✅ Все шаблоны готовы к использованию!" 