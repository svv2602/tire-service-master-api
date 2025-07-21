template = EmailTemplate.create!(
  name: 'Підтвердження бронювання (UK)',
  subject: 'Ваше бронювання підтверджено - {service_name}',
  body: "Шановний(а) {client_name}!\n\nВаше бронювання успішно підтверджено.\n\nДеталі:\n📅 Дата: {booking_date}\n🕒 Час: {booking_time}\n🏢 Точка: {service_point_name}\n\nДякуємо!",
  template_type: 'booking_confirmation',
  language: 'uk',
  variables: '["client_name", "booking_date", "booking_time", "service_point_name", "service_name"]',
  description: 'Тестовий шаблон підтвердження бронювання'
)
puts "✅ Створено шаблон: #{template.name}"

template2 = EmailTemplate.create!(
  name: 'Нагадування про бронювання (UK)',
  subject: 'Нагадування: завтра у вас запис - {service_name}',
  body: "Шановний(а) {client_name}!\n\nНагадуємо про ваше бронювання завтра:\n\n📅 Дата: {booking_date}\n🕒 Час: {booking_time}\n🏢 Точка: {service_point_name}\n\nДо зустрічі!",
  template_type: 'booking_reminder',
  language: 'uk',
  variables: '["client_name", "booking_date", "booking_time", "service_point_name", "service_name"]',
  description: 'Нагадування про бронювання'
)
puts "✅ Створено шаблон: #{template2.name}"

puts "📧 Всього email шаблонів: #{EmailTemplate.count}" 