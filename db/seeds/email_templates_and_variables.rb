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
  # 1. Подтверждение бронирования
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

  # 2. Напоминание о записи
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

  # 3. Завершение обслуживания
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

  # 4. Отмена бронирования
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

  # 5. Приглашение на техосмотр
  {
    name: 'Запрошення на техогляд',
    template_type: 'maintenance_invitation',
    subject: 'Час для техогляду вашого {car_brand} {car_model}',
    body: %{
Вітаємо, {client_name}!

Рекомендуємо пройти плановий техогляд вашого автомобіля {car_brand} {car_model}.

🔧 РЕКОМЕНДОВАНІ ПОСЛУГИ:
• Перевірка стану шин
• Балансування коліс  
• Діагностика підвіски
• Заміна масла

{seasonal_recommendation}

{weather_warning}

📅 ЗАПИСАТИСЯ МОЖНА:
• Онлайн: {website_url}
• Телефон: {support_phone}

🏢 НАШІ СЕРВІСНІ ТОЧКИ:
Оберіть найближчу до вас локацію на нашому сайті.

{current_promotion}

{loyalty_bonus}

{additional_services}

З турботою про вашу безпеку,
Команда {company_name}
📧 {support_email}
    }.strip,
    is_active: true
  },

  # 6. Благодарность за отзыв
  {
    name: 'Подяка за відгук',
    template_type: 'review_thanks',
    subject: 'Дякуємо за ваш відгук!',
    body: %{
{client_name}, дякуємо за відгук!

Ваша думка дуже важлива для нас і допомагає покращувати якість обслуговування.

⭐ Ви оцінили наш сервіс після обслуговування:
• Дата візиту: {booking_date}
• Послуга: {service_name}
• Сервісна точка: {service_point_name}

{loyalty_bonus}

{current_promotion}

Будемо раді бачити вас знову!

{weekend_hours}

{additional_services}

З повагою,
Команда {company_name}
📧 {support_email}
📞 {support_phone}
🌐 {website_url}
    }.strip,
    is_active: true
  }
]

email_templates_data.each_with_index do |template_data, index|
  template = EmailTemplate.create!(
    name: template_data[:name],
    template_type: template_data[:template_type],
    subject: template_data[:subject],
    body: template_data[:body],
    is_active: template_data[:is_active],
    language: 'uk'  # Украинский язык
  )
  
  puts "✅ Створений email шаблон: #{template.name} (ID: #{template.id})"
  
  # Привязываем кастомные переменные к шаблонам
  case template.template_type
  when 'booking_confirmation'
    # К подтверждению привязываем акции и дополнительные услуги
    custom_vars = CustomVariable.where(name: ['current_promotion', 'additional_services'])
  when 'booking_reminder'  
    # К напоминанию - погода и сезонные рекомендации
    custom_vars = CustomVariable.where(name: ['weather_warning', 'seasonal_recommendation', 'emergency_contact'])
  when 'service_completed'
    # К завершению - гарантия и бонусы
    custom_vars = CustomVariable.where(name: ['warranty_info', 'loyalty_bonus', 'current_promotion', 'weekend_hours'])
  when 'booking_cancelled'
    # К отмене - акции и контакты
    custom_vars = CustomVariable.where(name: ['current_promotion', 'emergency_contact'])
  when 'maintenance_invitation'
    # К приглашению - сезонные советы и погода
    custom_vars = CustomVariable.where(name: ['seasonal_recommendation', 'weather_warning', 'current_promotion', 'loyalty_bonus', 'additional_services'])
  when 'review_thanks'
    # К благодарности - бонусы и акции  
    custom_vars = CustomVariable.where(name: ['loyalty_bonus', 'current_promotion', 'weekend_hours', 'additional_services'])
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