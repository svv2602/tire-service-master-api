# Email Templates and Custom Variables Seeds
# Создание распространенных email шаблонов и примеров кастомных переменных на украинском языке

puts "🌱 Создание email шаблонов и кастомных переменных..."

# Получаем администратора для создания переменных
admin_user = User.find_by(email: 'admin@test.com') || User.where(role: UserRole.find_by(name: 'admin')).first || User.first

if admin_user.nil?
  puts "❌ Не найден администратор для создания переменных"
  return
end

puts "👤 Используем администратора: #{admin_user.email}"

# =====================================================
# КАСТОМНЫЕ ПЕРЕМЕННЫЕ (примеры)
# =====================================================

puts "📝 Создание кастомных переменных..."

custom_variables_data = [
  # Погодные условия
  {
    name: 'weather_warning',
    category: 'custom',
    description: 'Попередження про погодні умови',
    example_value: 'Увага! Завтра очікується дощ. Рекомендуємо зимові шини для безпечної їзди.'
  },
  {
    name: 'seasonal_recommendation',
    category: 'custom', 
    description: 'Сезонні рекомендації по шинах',
    example_value: 'З настанням зими радимо перейти на зимові шини для вашої безпеки.'
  },
  
  # Акции и скидки
  {
    name: 'current_promotion',
    category: 'custom',
    description: 'Поточна акція або знижка',
    example_value: 'Спеціальна пропозиція: знижка 15% на всі зимові шини до кінця місяця!'
  },
  {
    name: 'loyalty_bonus',
    category: 'custom',
    description: 'Бонус за лояльність',
    example_value: 'Як наш постійний клієнт, ви отримуєте додаткову знижку 5%'
  },
  
  # Дополнительные услуги
  {
    name: 'additional_services',
    category: 'custom',
    description: 'Додаткові послуги',
    example_value: 'Також пропонуємо: балансування коліс, заміну масла, діагностику підвіски'
  },
  {
    name: 'warranty_info',
    category: 'custom',
    description: 'Інформація про гарантію',
    example_value: 'Гарантія на встановлені шини складає 12 місяців або 20000 км пробігу'
  },
  
  # Контакты и время работы
  {
    name: 'emergency_contact',
    category: 'custom',
    description: 'Екстрений контакт',
    example_value: 'У випадку термінових питань телефонуйте: +380501234567 (цілодобово)'
  },
  {
    name: 'weekend_hours',
    category: 'custom',
    description: 'Режим роботи у вихідні',
    example_value: 'Вихідні: субота 9:00-15:00, неділя - вихідний'
  }
]

custom_variables_data.each do |var_data|
  variable = CustomVariable.find_or_create_by(name: var_data[:name]) do |var|
    var.category = var_data[:category]
    var.description = var_data[:description]
    var.example_value = var_data[:example_value]
    var.is_active = true
    var.created_by = admin_user
  end
  
  if variable.persisted?
    puts "✅ Створена змінна: #{variable.name}"
  else
    puts "❌ Помилка створення змінної #{var_data[:name]}: #{variable.errors.full_messages.join(', ')}"
  end
end

# =====================================================
# EMAIL ШАБЛОНЫ
# =====================================================

puts "📧 Создание email шаблонов..."

email_templates_data = [
  # 1. Подтверждение бронирования (существующий тип)
  {
    name: 'Підтвердження бронювання',
    template_type: 'booking_confirmation',
    subject: 'Ваше бронювання підтверджено - {service_point_name}',
    body: %{
Вітаємо, {client_name}!

Ваше бронювання успішно підтверджено.

📋 ДЕТАЛІ БРОНЮВАННЯ:
• Дата: {booking_date}
• Час: {booking_time}
• Послуга: {service_name}
• Номер бронювання: {booking_id}

🏢 СЕРВІСНА ТОЧКА:
{service_point_name}
📍 Адреса: {service_point_address}
📞 Телефон: {service_point_phone}

🚗 АВТОМОБІЛЬ:
{car_brand} {car_model}
Номер: {license_plate}

{current_promotion}

{additional_services}

З повагою,
Команда {company_name}
📧 {support_email}
📞 {support_phone}
    }.strip,
    is_active: true
  },

  # 2. Напоминание о записи (существующий тип)
  {
    name: 'Нагадування про запис',
    template_type: 'booking_reminder', 
    subject: 'Нагадування: ваш запис завтра о {booking_time}',
    body: %{
Доброго дня, {client_name}!

Нагадуємо про ваш запис:

⏰ ЗАВТРА, {booking_date} о {booking_time}
🏢 {service_point_name}
📍 {service_point_address}
🔧 Послуга: {service_name}

🚗 Автомобіль: {car_brand} {car_model} ({license_plate})

{weather_warning}

{seasonal_recommendation}

📞 Якщо потрібно перенести запис, телефонуйте: {service_point_phone}

{emergency_contact}

До зустрічі!
Команда {company_name}
    }.strip,
    is_active: true
  },

  # 3. Отмена бронирования (существующий тип)
  {
    name: 'Скасування бронювання',
    template_type: 'booking_cancelled',
    subject: 'Бронювання скасовано - {booking_id}',
    body: %{
{client_name}, повідомляємо про скасування.

❌ СКАСОВАНЕ БРОНЮВАННЯ:
• Номер: {booking_id}
• Дата: {booking_date}
• Час: {booking_time}
• Послуга: {service_name}
• Сервісна точка: {service_point_name}

Ви можете створити нове бронювання на нашому сайті {website_url} або зателефонувати нам.

{current_promotion}

📞 Контакти для нового запису:
• {service_point_phone} - {service_point_name}
• {support_phone} - загальна підтримка

{emergency_contact}

Дякуємо за розуміння!
Команда {company_name}
    }.strip,
    is_active: true
  },

  # 4. Завершение обслуживания (существующий тип)
  {
    name: 'Завершення обслуговування',
    template_type: 'service_completed',
    subject: 'Дякуємо за візит! Обслуговування завершено',
    body: %{
Дякуємо, {client_name}!

Ваш автомобіль {car_brand} {car_model} успішно обслужений.

✅ ВИКОНАНІ РОБОТИ:
• Послуга: {service_name}
• Дата: {booking_date}
• Час: {booking_time}
• Сервісна точка: {service_point_name}

{warranty_info}

{loyalty_bonus}

🌟 ОЦІНІТЬ НАШ СЕРВІС:
Будь ласка, залишіть відгук про якість обслуговування на нашому сайті {website_url}

{current_promotion}

{weekend_hours}

З повагою,
Команда {company_name}
📧 {support_email}
📞 {support_phone}
    }.strip,
    is_active: true
  },

  # 5. Запрос отзыва (существующий тип)
  {
    name: 'Запит відгуку',
    template_type: 'review_request',
    subject: 'Оцініть якість нашого сервісу',
    body: %{
Вітаємо, {client_name}!

Сподіваємось, ви залишились задоволені якістю обслуговування в {service_point_name}.

⭐ ПОДІЛІТЬСЯ ВРАЖЕННЯМИ:
Ваш відгук допоможе нам покращити сервіс і допомогти іншим клієнтам.

📝 Залишити відгук можна:
• На нашому сайті: {website_url}
• Телефонувати: {support_phone}

🔧 ДЕТАЛІ ВІЗИТУ:
• Дата: {booking_date}
• Послуга: {service_name}
• Автомобіль: {car_brand} {car_model}

{current_promotion}

{loyalty_bonus}

Дякуємо за довіру!
Команда {company_name}
📧 {support_email}
    }.strip,
    is_active: true
  },

  # 6. Приветствие пользователя (существующий тип)
  {
    name: 'Вітання нового користувача',
    template_type: 'user_welcome',
    subject: 'Ласкаво просимо до {company_name}!',
    body: %{
Вітаємо, {client_name}!

Дякуємо за реєстрацію в системі {company_name}!

🎉 ВИ ТЕПЕР МАЄТЕ ДОСТУП ДО:
• Онлайн бронювання послуг
• Історії ваших візитів
• Персональних знижок і акцій
• Нагадувань про техогляд

🏢 НАШІ ПОСЛУГИ:
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

  # 7. Сброс пароля (существующий тип)
  {
    name: 'Скидання пароля',
    template_type: 'password_reset',
    subject: 'Скидання пароля - {company_name}',
    body: %{
Вітаємо, {client_name}!

Ви запросили скидання пароля для вашого облікового запису.

🔐 ДЛЯ СКИДАННЯ ПАРОЛЯ:
Перейдіть за посиланням нижче та створіть новий пароль.

⚠️ БЕЗПЕКА:
• Посилання дійсне протягом 24 годин
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

  # 8. Рассылка (новый тип)
  {
    name: 'Інформаційна розсилка',
    template_type: 'newsletter',
    subject: 'Новини та акції від {company_name}',
    body: %{
Вітаємо, {client_name}!

📢 НОВИНИ ТА АКЦІЇ ЦЬОГО МІСЯЦЯ:

{current_promotion}

🔧 КОРИСНІ ПОРАДИ:
{seasonal_recommendation}

{weather_warning}

🏆 ПЕРЕВАГИ ДЛЯ ПОСТІЙНИХ КЛІЄНТІВ:
{loyalty_bonus}

🆕 НОВІ ПОСЛУГИ:
{additional_services}

📋 РЕКОМЕНДАЦІЇ ПО ТЕХОГЛЯДУ:
Не забувайте про регулярне обслуговування вашого автомобіля.

{warranty_info}

📞 ЗВ'ЯЗОК З НАМИ:
• Сайт: {website_url}
• Email: {support_email}
• Телефон: {support_phone}

{weekend_hours}

{emergency_contact}

Дякуємо, що обираєте нас!
Команда {company_name}
    }.strip,
    is_active: true
  },

  # ===== НОВЫЕ ШАБЛОНЫ ДЛЯ РАСШИРЕННЫХ СОБЫТИЙ =====

  # 8. Изменение времени бронирования
  {
    name: 'Зміна часу бронювання',
    template_type: 'booking_time_changed',
    subject: 'Зміна часу вашого бронювання - {service_point_name}',
    body: %{
Вітаємо, {client_name}!

Час вашого бронювання було змінено.

📅 ОНОВЛЕНІ ДАНІ:
• Нова дата: {booking_date}
• Новий час: {booking_time}
• Номер бронювання: {booking_id}

🏢 СЕРВІСНА ТОЧКА:
{service_point_name}
📍 Адреса: {service_point_address}
📞 Телефон: {service_point_phone}

🚗 АВТОМОБІЛЬ:
{car_brand} {car_model}
Номер: {license_plate}

ℹ️ Якщо ви не запитували зміну часу, зверніться до нашої служби підтримки.

З повагою,
Команда {company_name}
📧 {support_email}
📞 {support_phone}
    }.strip,
    is_active: true
  },

  # 9. Изменение сервисной точки
  {
    name: 'Зміна сервісної точки',
    template_type: 'booking_location_changed',
    subject: 'Зміна місця обслуговування - {booking_id}',
    body: %{
Вітаємо, {client_name}!

Місце вашого обслуговування було змінено.

🏢 НОВА СЕРВІСНА ТОЧКА:
{service_point_name}
📍 Адреса: {service_point_address}
📞 Телефон: {service_point_phone}
🌐 Місто: {service_point_city}

📅 ДАТА ТА ЧАС:
• Дата: {booking_date}
• Час: {booking_time}
• Номер бронювання: {booking_id}

🚗 АВТОМОБІЛЬ:
{car_brand} {car_model}
Номер: {license_plate}

🗺️ ЯК ДІСТАТИСЯ:
Рекомендуємо заздалегідь ознайомитися з розташуванням нової точки на карті.

ℹ️ Якщо у вас є питання щодо зміни локації, зверніться до нашої служби підтримки.

З повагою,
Команда {company_name}
📧 {support_email}
📞 {support_phone}
    }.strip,
    is_active: true
  },

  # 10. Изменение данных клиента
  {
    name: 'Зміна даних клієнта',
    template_type: 'booking_client_info_changed',
    subject: 'Оновлення даних вашого бронювання - {booking_id}',
    body: %{
Вітаємо, {client_name}!

Дані вашого бронювання було оновлено.

📋 БРОНЮВАННЯ:
• Номер: {booking_id}
• Дата: {booking_date}
• Час: {booking_time}

🏢 СЕРВІСНА ТОЧКА:
{service_point_name}
📍 Адреса: {service_point_address}

👤 ОНОВЛЕНІ КОНТАКТНІ ДАНІ:
• Ім'я: {client_first_name} {client_last_name}
• Телефон: {client_phone}
• Email: {client_email}

🚗 АВТОМОБІЛЬ:
{car_brand} {car_model}
Номер: {license_plate}

✅ Ваше бронювання залишається активним з оновленими даними.

ℹ️ Якщо ви не запитували зміну даних, негайно зверніться до нашої служби підтримки.

З повагою,
Команда {company_name}
📧 {support_email}
📞 {support_phone}
    }.strip,
    is_active: true
  }
]

email_templates_data.each_with_index do |template_data, index|
  template = EmailTemplate.find_or_create_by!(
    template_type: template_data[:template_type],
    language: 'uk'  # Украинский язык
  ) do |t|
    t.name = template_data[:name]
    t.subject = template_data[:subject]
    t.body = template_data[:body]
    t.is_active = template_data[:is_active]
  end
  
  puts "✅ Створений/оновлений email шаблон: #{template.name} (ID: #{template.id})"
  
  # Привязываем кастомные переменные к шаблонам
  case template.template_type
  when 'booking_confirmation'
    # К подтверждению привязываем акции и дополнительные услуги
    custom_vars = CustomVariable.where(name: ['current_promotion', 'additional_services'])
  when 'booking_reminder'  
    # К напоминанию - погода и сезонные рекомендации
    custom_vars = CustomVariable.where(name: ['weather_warning', 'seasonal_recommendation', 'emergency_contact'])
  when 'booking_cancelled'
    # К отмене - акции и контакты
    custom_vars = CustomVariable.where(name: ['current_promotion', 'emergency_contact'])
  when 'service_completed'
    # К завершению - гарантия и бонусы
    custom_vars = CustomVariable.where(name: ['warranty_info', 'loyalty_bonus', 'current_promotion', 'weekend_hours'])
  when 'review_request'
    # К запросу отзыва - акции и бонусы
    custom_vars = CustomVariable.where(name: ['current_promotion', 'loyalty_bonus'])
  when 'user_welcome'
    # К приветствию - акции и дополнительные услуги
    custom_vars = CustomVariable.where(name: ['current_promotion', 'additional_services'])
  when 'password_reset'
    # К сбросу пароля - экстренные контакты
    custom_vars = CustomVariable.where(name: ['emergency_contact'])
  when 'newsletter'
    # К рассылке - все переменные для максимальной гибкости
    custom_vars = CustomVariable.all
  else
    custom_vars = CustomVariable.none
  end
  
  # Создаем связи между шаблоном и переменными
  custom_vars.each do |var|
    EmailTemplateCustomVariable.find_or_create_by(
      email_template: template,
      custom_variable: var
    )
    puts "  🔗 Привязана переменная: #{var.name}"
  end
end

puts ""
puts "🎉 Seeds завершены!"
puts "📧 Создано email шаблонов: #{EmailTemplate.count}"
puts "📝 Создано кастомных переменных: #{CustomVariable.count}"
puts "🔗 Создано связей шаблон-переменная: #{EmailTemplateCustomVariable.count}"
puts ""
puts "🌐 Все тексты на украинском языке для клиентов"
puts "✅ Готово к использованию в админ-панели!" 