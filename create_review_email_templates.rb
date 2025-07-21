#!/usr/bin/env ruby

puts '📝 СОЗДАНИЕ EMAIL ШАБЛОНОВ ДЛЯ УВЕДОМЛЕНИЙ ОБ ОТЗЫВАХ'
puts '================================================='

# Удаляем существующие шаблоны об отзывах
EmailTemplate.where(template_type: ['admin_new_review', 'review_published', 'review_rejected']).destroy_all

# Шаблоны для уведомлений об отзывах
review_templates = [
  {
    name: 'Новий відгук (для адміністратора)',
    template_type: 'admin_new_review',
    subject: 'Новий відгук {review_number} - {service_point_name}',
    body: %{<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Новий відгук</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h1 style="color: #2c5aa0; border-bottom: 2px solid #2c5aa0; padding-bottom: 10px;">
      📝 Новий відгук #{review_number}
    </h1>
    
    <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h3 style="color: #495057; margin-top: 0;">Деталі відгуку:</h3>
      <p><strong>Номер відгуку:</strong> {review_number}</p>
      <p><strong>Оцінка:</strong> {rating_stars} ({rating}/5)</p>
      <p><strong>Статус:</strong> {status_text}</p>
      <p><strong>Дата створення:</strong> {created_date} о {created_time}</p>
      <p><strong>Коментар:</strong><br>{comment}</p>
    </div>
    
    <div style="background: #e3f2fd; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h3 style="color: #1976d2; margin-top: 0;">👤 Клієнт:</h3>
      <p><strong>Ім'я:</strong> {client_first_name} {client_last_name}</p>
      <p><strong>Email:</strong> {client_email}</p>
      <p><strong>Телефон:</strong> {client_phone}</p>
    </div>
    
    <div style="background: #fff3e0; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h3 style="color: #f57c00; margin-top: 0;">🏢 Сервісна точка:</h3>
      <p><strong>Назва:</strong> {service_point_name}</p>
      <p><strong>Адреса:</strong> {service_point_address}</p>
      <p><strong>Місто:</strong> {city_name}</p>
    </div>
    
    <div style="text-align: center; margin: 30px 0;">
      <p style="color: #666; font-style: italic;">Відгук потребує модерації в адмін-панелі</p>
    </div>
    
    <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
    <p style="color: #666; font-size: 12px; text-align: center;">
      Це автоматичне повідомлення від системи Tire Service.<br>
      Для модерації відгуку перейдіть в адмін-панель.
    </p>
  </div>
</body>
</html>}.strip,
    language: 'uk',
    is_active: true
  },
  
  {
    name: 'Відгук опубліковано (для клієнта)',
    template_type: 'review_published',
    subject: 'Ваш відгук {review_number} опубліковано!',
    body: %{<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Відгук опубліковано</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h1 style="color: #4caf50; border-bottom: 2px solid #4caf50; padding-bottom: 10px;">
      ✅ Ваш відгук опубліковано!
    </h1>
    
    <p>Шановний(а) {client_first_name} {client_last_name}!</p>
    
    <p>Дякуємо за ваш відгук! Ми раді повідомити, що ваш відгук успішно пройшов модерацію та опубліковано на нашому сайті.</p>
    
    <div style="background: #e8f5e8; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h3 style="color: #2e7d32; margin-top: 0;">Деталі вашого відгуку:</h3>
      <p><strong>Номер відгуку:</strong> {review_number}</p>
      <p><strong>Оцінка:</strong> {rating_stars} ({rating}/5)</p>
      <p><strong>Дата публікації:</strong> {created_date}</p>
      <p><strong>Коментар:</strong><br>{comment}</p>
    </div>
    
    <div style="background: #fff3e0; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h3 style="color: #f57c00; margin-top: 0;">🏢 Сервісна точка:</h3>
      <p><strong>Назва:</strong> {service_point_name}</p>
      <p><strong>Адреса:</strong> {service_point_address}</p>
      <p><strong>Місто:</strong> {city_name}</p>
    </div>
    
    <div style="text-align: center; margin: 30px 0;">
      <p style="color: #4caf50; font-weight: bold;">Дякуємо за довіру та зворотний зв'язок!</p>
      <p>Ваша думка допомагає нам ставати кращими.</p>
    </div>
    
    <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
    <p style="color: #666; font-size: 12px; text-align: center;">
      Це автоматичне повідомлення від системи Tire Service.<br>
      З питань звертайтеся за телефоном: {service_point_phone}
    </p>
  </div>
</body>
</html>}.strip,
    language: 'uk',
    is_active: true
  },
  
  {
    name: 'Відгук відхилено (для клієнта)',
    template_type: 'review_rejected',
    subject: 'Ваш відгук {review_number} потребує уточнення',
    body: %{<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Відгук потребує уточнення</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h1 style="color: #ff9800; border-bottom: 2px solid #ff9800; padding-bottom: 10px;">
      ⚠️ Ваш відгук потребує уточнення
    </h1>
    
    <p>Шановний(а) {client_first_name} {client_last_name}!</p>
    
    <p>Дякуємо за ваш відгук! На жаль, ваш відгук не може бути опубліковано в поточному вигляді через невідповідність нашим правилам публікації відгуків.</p>
    
    <div style="background: #fff3e0; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h3 style="color: #f57c00; margin-top: 0;">Деталі вашого відгуку:</h3>
      <p><strong>Номер відгуку:</strong> {review_number}</p>
      <p><strong>Оцінка:</strong> {rating_stars} ({rating}/5)</p>
      <p><strong>Дата подання:</strong> {created_date}</p>
      <p><strong>Коментар:</strong><br>{comment}</p>
    </div>
    
    <div style="background: #ffebee; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <h3 style="color: #c62828; margin-top: 0;">📋 Можливі причини:</h3>
      <ul>
        <li>Використання нецензурної лексики</li>
        <li>Особиста інформація третіх осіб</li>
        <li>Неконструктивна критика</li>
        <li>Порушення правил спільноти</li>
      </ul>
    </div>
    
    <div style="text-align: center; margin: 30px 0;">
      <p style="color: #666;">Якщо у вас є питання щодо причин відхилення відгуку,<br>будь ласка, зверніться до нашої служби підтримки.</p>
      <p style="color: #ff9800; font-weight: bold;">Дякуємо за розуміння!</p>
    </div>
    
    <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
    <p style="color: #666; font-size: 12px; text-align: center;">
      Це автоматичне повідомлення від системи Tire Service.<br>
      З питань звертайтеся за телефоном: {service_point_phone}
    </p>
  </div>
</body>
</html>}.strip,
    language: 'uk',
    is_active: true
  }
]

# Создаем шаблоны
review_templates.each do |template_data|
  template = EmailTemplate.create!(template_data)
  puts "✅ Создан шаблон: #{template.name} (#{template.template_type})"
end

puts "\n📊 ИТОГО:"
puts "Создано #{review_templates.length} шаблонов для уведомлений об отзывах"
puts "Всего шаблонов в системе: #{EmailTemplate.count}"

puts "\n🎯 ГОТОВО! Система уведомлений об отзывах настроена." 