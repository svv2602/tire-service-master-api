#!/usr/bin/env ruby

puts "🆕 ДОБАВЛЕНИЕ НОВЫХ EMAIL ШАБЛОНОВ"
puts "=================================="

# Новые шаблоны для расширенных событий
new_templates = [
  # 1. Изменение времени бронирования
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

  # 2. Изменение сервисной точки
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

  # 3. Изменение данных клиента
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

# Создаем новые шаблоны
created_count = 0
new_templates.each do |template_data|
  template = EmailTemplate.find_or_create_by(
    template_type: template_data[:template_type],
    language: 'uk'
  ) do |t|
    t.name = template_data[:name]
    t.subject = template_data[:subject]
    t.body = template_data[:body]
    t.is_active = template_data[:is_active]
  end
  
  if template.persisted? && template.created_at > 1.minute.ago
    puts "✅ Создан шаблон: #{template.name} (#{template.template_type})"
    created_count += 1
  else
    puts "ℹ️ Шаблон уже существует: #{template.template_type}"
  end
end

puts ""
puts "🎉 РЕЗУЛЬТАТ:"
puts "📧 Создано новых шаблонов: #{created_count}"
puts "📝 Всего шаблонов в системе: #{EmailTemplate.count}"
puts ""
puts "✅ Готово! Новые типы уведомлений доступны:"
puts "   - booking_time_changed"
puts "   - booking_location_changed" 
puts "   - booking_client_info_changed" 