#!/usr/bin/env ruby

puts '📧 СОЗДАНИЕ БАЗОВЫХ EMAIL ШАБЛОНОВ'
puts '================================='

# Создаем несколько базовых шаблонов для тестирования API
templates = [
  {
    name: 'Підтвердження бронювання (базовий)',
    template_type: 'booking_confirmation',
    subject: 'Ваше бронювання {booking_number} підтверджено',
    body: %{
<h1>Дякуємо за бронювання!</h1>
<p>Шановний(а) {client_first_name} {client_last_name}!</p>
<p>Ваше бронювання <strong>{booking_number}</strong> успішно підтверджено.</p>
<p><strong>Деталі:</strong></p>
<ul>
  <li>Дата: {booking_date}</li>
  <li>Час: {start_time}</li>
  <li>Сервісна точка: {service_point_name}</li>
  <li>Адреса: {service_point_address}</li>
</ul>
<p>Очікуємо вас!</p>
    }.strip,
    language: 'uk',
    is_active: true
  },
  
  {
    name: 'Новий відгук (для адміністратора)',
    template_type: 'admin_new_review',
    subject: 'Новий відгук {review_number}',
    body: %{
<h1>Новий відгук від клієнта</h1>
<p><strong>Клієнт:</strong> {client_first_name} {client_last_name}</p>
<p><strong>Оцінка:</strong> {rating}/5</p>
<p><strong>Коментар:</strong></p>
<blockquote>{comment}</blockquote>
<p><strong>Сервісна точка:</strong> {service_point_name}</p>
<p>Потребує модерації в адмін-панелі.</p>
    }.strip,
    language: 'uk',
    is_active: true
  },
  
  {
    name: 'Нова сервісна точка (для адміністратора)',
    template_type: 'admin_service_point_created',
    subject: 'Створена нова сервісна точка {service_point_name}',
    body: %{
<h1>Створена нова сервісна точка</h1>
<p><strong>Назва:</strong> {service_point_name}</p>
<p><strong>Адреса:</strong> {service_point_address}</p>
<p><strong>Місто:</strong> {city_name}</p>
<p><strong>Статус:</strong> {work_status_text}</p>
<p><strong>Дата створення:</strong> {created_date}</p>
<p>Перевірте налаштування в адмін-панелі.</p>
    }.strip,
    language: 'uk',
    is_active: true
  }
]

# Удаляем существующие тестовые шаблоны
existing_names = templates.map { |t| t[:name] }
deleted_count = EmailTemplate.where(name: existing_names).count
EmailTemplate.where(name: existing_names).destroy_all
puts "🗑️ Удалено старых шаблонов: #{deleted_count}"

# Создаем новые шаблоны
created_count = 0
templates.each do |template_data|
  begin
    template = EmailTemplate.create!(template_data)
    puts "✅ Создан: #{template.name} (#{template.template_type})"
    created_count += 1
  rescue => e
    puts "❌ Ошибка создания #{template_data[:name]}: #{e.message}"
    puts "   #{e.backtrace.first}"
  end
end

puts "\n📊 РЕЗУЛЬТАТ:"
puts "Создано шаблонов: #{created_count}"
puts "Всего в системе: #{EmailTemplate.count}"

# Тестируем API методы
puts "\n🧪 ТЕСТИРОВАНИЕ API МЕТОДОВ"
puts "=========================="

if EmailTemplate.any?
  template = EmailTemplate.first
  puts "✅ Тестовый шаблон: #{template.name}"
  
  # Тестируем сериализацию
  begin
    controller = Api::V1::EmailTemplatesController.new
    serialized = controller.send(:serialize_template, template)
    puts "✅ Сериализация работает: #{serialized.keys.join(', ')}"
  rescue => e
    puts "❌ Ошибка сериализации: #{e.message}"
  end
  
  # Тестируем получение переменных
  begin
    controller = Api::V1::EmailTemplatesController.new
    variables = controller.send(:get_available_variables, template.template_type)
    puts "✅ Переменные получены: #{variables.length} штук"
  rescue => e
    puts "❌ Ошибка получения переменных: #{e.message}"
  end
  
  # Тестируем тестовые данные
  begin
    controller = Api::V1::EmailTemplatesController.new
    test_vars = controller.send(:get_test_variables, template.template_type)
    puts "✅ Тестовые данные: #{test_vars.keys.length} переменных"
  rescue => e
    puts "❌ Ошибка тестовых данных: #{e.message}"
  end
end

puts "\n🎯 ГОТОВО! Базовые шаблоны созданы для тестирования API." 