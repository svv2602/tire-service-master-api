#!/usr/bin/env ruby

puts '📱 МИГРАЦИЯ TELEGRAM ШАБЛОНОВ В БАЗУ ДАННЫХ'
puts '==========================================='

# Определяем шаблоны Telegram (взятые из фронтенда)
telegram_templates = [
  {
    name: 'Підтвердження запису',
    name_ru: 'Подтверждение записи',
    template_type: 'booking_confirmation',
    template_uk: '✅ Ваш запис підтверджено!\n\n📅 Дата: {booking_date}\n🕐 Час: {start_time}\n📍 Адреса: {service_point_address}\n🚗 Послуга: {service_category_name}\n\nОчікуємо вас!',
    template_ru: '✅ Ваша запись подтверждена!\n\n📅 Дата: {booking_date}\n🕐 Время: {start_time}\n📍 Адрес: {service_point_address}\n🚗 Услуга: {service_category_name}\n\nОжидаем вас!',
    variables: ['booking_date', 'start_time', 'service_point_address', 'service_category_name'],
  },
  {
    name: 'Нагадування про запис',
    name_ru: 'Напоминание о записи',
    template_type: 'booking_reminder',
    template_uk: '⏰ Нагадуємо про ваш запис завтра!\n\n📅 Дата: {booking_date}\n🕐 Час: {start_time}\n📍 Адреса: {service_point_address}\n\nДо зустрічі!',
    template_ru: '⏰ Напоминаем о вашей записи завтра!\n\n📅 Дата: {booking_date}\n🕐 Время: {start_time}\n📍 Адрес: {service_point_address}\n\nДо встречи!',
    variables: ['booking_date', 'start_time', 'service_point_address'],
  },
  {
    name: 'Зміна статусу',
    name_ru: 'Изменение статуса',
    template_type: 'booking_status_changed',
    template_uk: '📢 Статус вашого запису змінено: {status_text}\n\n📅 Дата: {booking_date}\n🕐 Час: {start_time}\n\n{additional_info}',
    template_ru: '📢 Статус вашей записи изменен: {status_text}\n\n📅 Дата: {booking_date}\n🕐 Время: {start_time}\n\n{additional_info}',
    variables: ['status_text', 'booking_date', 'start_time', 'additional_info'],
  },
  {
    name: 'Скасування запису',
    name_ru: 'Отмена записи',
    template_type: 'booking_cancelled',
    template_uk: '❌ Ваш запис скасовано\n\n📅 Дата: {booking_date}\n🕐 Час: {start_time}\n📍 Адреса: {service_point_address}\n\n💬 Причина: {cancellation_reason}',
    template_ru: '❌ Ваша запись отменена\n\n📅 Дата: {booking_date}\n🕐 Время: {start_time}\n📍 Адрес: {service_point_address}\n\n💬 Причина: {cancellation_reason}',
    variables: ['booking_date', 'start_time', 'service_point_address', 'cancellation_reason'],
  },
  {
    name: 'Вітання нового користувача',
    name_ru: 'Приветствие нового пользователя',
    template_type: 'user_welcome',
    template_uk: '👋 Вітаємо, {client_first_name}!\n\nВи успішно зареєстровані в системі шиномонтажу.\n\n🚗 Тепер ви можете:\n• Записуватися на обслуговування\n• Переглядати історію записів\n• Залишати відгуки\n\nБажаємо приємного користування!',
    template_ru: '👋 Добро пожаловать, {client_first_name}!\n\nВы успешно зарегистрированы в системе шиномонтажа.\n\n🚗 Теперь вы можете:\n• Записываться на обслуживание\n• Просматривать историю записей\n• Оставлять отзывы\n\nЖелаем приятного пользования!',
    variables: ['client_first_name'],
  },
  {
    name: 'Запит відгуку',
    name_ru: 'Запрос отзыва',
    template_type: 'review_request',
    template_uk: '⭐ Як вам наше обслуговування?\n\n📅 Дата: {booking_date}\n📍 {service_point_name}\n🚗 {service_category_name}\n\nБудемо вдячні за ваш відгук! Це допоможе нам стати кращими.',
    template_ru: '⭐ Как вам наше обслуживание?\n\n📅 Дата: {booking_date}\n📍 {service_point_name}\n🚗 {service_category_name}\n\nБудем благодарны за ваш отзыв! Это поможет нам стать лучше.',
    variables: ['booking_date', 'service_point_name', 'service_category_name'],
  }
]

puts "\n🔍 ПРОВЕРКА СУЩЕСТВУЮЩИХ ШАБЛОНОВ"
puts "================================="

existing_telegram_count = EmailTemplate.telegram_templates.count
puts "Найдено существующих Telegram шаблонов: #{existing_telegram_count}"

puts "\n📝 СОЗДАНИЕ TELEGRAM ШАБЛОНОВ"
puts "============================="

created_count = 0
skipped_count = 0

telegram_templates.each do |template_data|
  # Создаем украинскую версию
  uk_template = EmailTemplate.find_or_initialize_by(
    template_type: template_data[:template_type],
    language: 'uk',
    channel_type: 'telegram'
  )
  
  if uk_template.new_record?
    uk_template.assign_attributes(
      name: template_data[:name],
      subject: nil, # Telegram не использует subject
      body: template_data[:template_uk],
      is_active: true,
      variables: template_data[:variables].to_json,
      description: "Автоматически созданный Telegram шаблон для #{template_data[:template_type]}"
    )
    
    if uk_template.save
      puts "✅ Создан: #{uk_template.name} (uk)"
      created_count += 1
    else
      puts "❌ Ошибка создания #{template_data[:name]} (uk): #{uk_template.errors.full_messages.join(', ')}"
    end
  else
    puts "⚠️ Пропущен: #{template_data[:name]} (uk) - уже существует"
    skipped_count += 1
  end

  # Создаем русскую версию
  ru_template = EmailTemplate.find_or_initialize_by(
    template_type: template_data[:template_type],
    language: 'ru',
    channel_type: 'telegram'
  )
  
  if ru_template.new_record?
    ru_template.assign_attributes(
      name: template_data[:name_ru],
      subject: nil, # Telegram не использует subject
      body: template_data[:template_ru],
      is_active: true,
      variables: template_data[:variables].to_json,
      description: "Автоматически созданный Telegram шаблон для #{template_data[:template_type]}"
    )
    
    if ru_template.save
      puts "✅ Создан: #{ru_template.name} (ru)"
      created_count += 1
    else
      puts "❌ Ошибка создания #{template_data[:name_ru]} (ru): #{ru_template.errors.full_messages.join(', ')}"
    end
  else
    puts "⚠️ Пропущен: #{template_data[:name_ru]} (ru) - уже существует"
    skipped_count += 1
  end
end

puts "\n📊 СТАТИСТИКА МИГРАЦИИ"
puts "====================="
puts "Создано новых шаблонов: #{created_count}"
puts "Пропущено существующих: #{skipped_count}"
puts "Всего Telegram шаблонов в БД: #{EmailTemplate.telegram_templates.count}"

puts "\n🧪 ТЕСТИРОВАНИЕ СОЗДАННЫХ ШАБЛОНОВ"
puts "=================================="

if EmailTemplate.telegram_templates.any?
  test_template = EmailTemplate.telegram_templates.first
  puts "Тестовый шаблон: #{test_template.name}"
  
  # Тестируем рендеринг
  test_vars = {
    'booking_date' => '2025-01-25',
    'start_time' => '10:00',
    'service_point_address' => 'ул. Тестовая, 123',
    'service_category_name' => 'Замена шин',
    'client_first_name' => 'Иван'
  }
  
  begin
    rendered = test_template.render_telegram_template(test_vars)
    puts "✅ Рендеринг успешен"
    puts "Сообщение: #{rendered[:message][0..100]}..."
    puts "Parse mode: #{rendered[:parse_mode]}"
  rescue => e
    puts "❌ Ошибка рендеринга: #{e.message}"
  end
end

puts "\n🎯 ГОТОВО! Telegram шаблоны мигрированы в единую систему."
puts "Теперь можно управлять ими через API /api/v1/email_templates?channel_type=telegram" 