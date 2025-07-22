# Telegram Templates Seeds
# Создание шаблонов уведомлений для Telegram канала

puts '📱 Создание Telegram шаблонов уведомлений...'

# Определяем шаблоны Telegram
telegram_templates_data = [
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
    name: 'Скасування запису',
    name_ru: 'Отмена записи',
    template_type: 'booking_cancelled',
    template_uk: '❌ Ваш запис скасовано\n\n📅 Дата: {booking_date}\n🕐 Час: {start_time}\n📍 Адреса: {service_point_address}\n\n💬 Причина: {cancellation_reason}',
    template_ru: '❌ Ваша запись отменена\n\n📅 Дата: {booking_date}\n🕐 Время: {start_time}\n📍 Адрес: {service_point_address}\n\n💬 Причина: {cancellation_reason}',
    variables: ['booking_date', 'start_time', 'service_point_address', 'cancellation_reason'],
  },
  {
    name: 'Завершення обслуговування',
    name_ru: 'Завершение обслуживания',
    template_type: 'service_completed',
    template_uk: '✅ Обслуговування завершено!\n\n📅 Дата: {booking_date}\n📍 {service_point_name}\n🚗 {service_category_name}\n\n💰 Сума: {total_amount} грн\n\n⭐ Будемо вдячні за ваш відгук!',
    template_ru: '✅ Обслуживание завершено!\n\n📅 Дата: {booking_date}\n📍 {service_point_name}\n🚗 {service_category_name}\n\n💰 Сумма: {total_amount} грн\n\n⭐ Будем благодарны за ваш отзыв!',
    variables: ['booking_date', 'service_point_name', 'service_category_name', 'total_amount'],
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
  },
  {
    name: 'Скидання пароля',
    name_ru: 'Сброс пароля',
    template_type: 'password_reset',
    template_uk: '🔐 Запит на скидання пароля\n\nВаш код підтвердження: {reset_code}\n\nКод дійсний протягом 15 хвилин.\n\nЯкщо ви не запитували скидання пароля, проігноруйте це повідомлення.',
    template_ru: '🔐 Запрос на сброс пароля\n\nВаш код подтверждения: {reset_code}\n\nКод действителен в течение 15 минут.\n\nЕсли вы не запрашивали сброс пароля, проигнорируйте это сообщение.',
    variables: ['reset_code'],
  },
  {
    name: 'Інформаційна розсилка',
    name_ru: 'Информационная рассылка',
    template_type: 'newsletter',
    template_uk: '📢 {newsletter_title}\n\n{newsletter_content}\n\n🚗 З повагою,\nКоманда шиномонтажу',
    template_ru: '📢 {newsletter_title}\n\n{newsletter_content}\n\n🚗 С уважением,\nКоманда шиномонтажа',
    variables: ['newsletter_title', 'newsletter_content'],
  }
]

created_count = 0
updated_count = 0
skipped_count = 0

telegram_templates_data.each do |template_data|
  # Создаем украинскую версию
  uk_template = EmailTemplate.find_or_initialize_by(
    template_type: template_data[:template_type],
    language: 'uk',
    channel_type: 'telegram'
  )
  
  template_attributes = {
    name: template_data[:name],
    subject: nil, # Telegram не использует subject
    body: template_data[:template_uk],
    is_active: true,
    variables: template_data[:variables].to_json,
    description: "Telegram шаблон для #{template_data[:template_type]}"
  }
  
  if uk_template.new_record?
    uk_template.assign_attributes(template_attributes)
    if uk_template.save
      puts "  ✅ Создан: #{uk_template.name} (uk)"
      created_count += 1
    else
      puts "  ❌ Ошибка создания #{template_data[:name]} (uk): #{uk_template.errors.full_messages.join(', ')}"
    end
  else
    # Обновляем существующий шаблон
    uk_template.assign_attributes(template_attributes)
    if uk_template.changed?
      if uk_template.save
        puts "  🔄 Обновлен: #{uk_template.name} (uk)"
        updated_count += 1
      else
        puts "  ❌ Ошибка обновления #{template_data[:name]} (uk): #{uk_template.errors.full_messages.join(', ')}"
      end
    else
      puts "  ⚠️ Без изменений: #{template_data[:name]} (uk)"
      skipped_count += 1
    end
  end

  # Создаем русскую версию
  ru_template = EmailTemplate.find_or_initialize_by(
    template_type: template_data[:template_type],
    language: 'ru',
    channel_type: 'telegram'
  )
  
  template_attributes_ru = {
    name: template_data[:name_ru],
    subject: nil, # Telegram не использует subject
    body: template_data[:template_ru],
    is_active: true,
    variables: template_data[:variables].to_json,
    description: "Telegram шаблон для #{template_data[:template_type]}"
  }
  
  if ru_template.new_record?
    ru_template.assign_attributes(template_attributes_ru)
    if ru_template.save
      puts "  ✅ Создан: #{ru_template.name} (ru)"
      created_count += 1
    else
      puts "  ❌ Ошибка создания #{template_data[:name_ru]} (ru): #{ru_template.errors.full_messages.join(', ')}"
    end
  else
    # Обновляем существующий шаблон
    ru_template.assign_attributes(template_attributes_ru)
    if ru_template.changed?
      if ru_template.save
        puts "  🔄 Обновлен: #{ru_template.name} (ru)"
        updated_count += 1
      else
        puts "  ❌ Ошибка обновления #{template_data[:name_ru]} (ru): #{ru_template.errors.full_messages.join(', ')}"
      end
    else
      puts "  ⚠️ Без изменений: #{template_data[:name_ru]} (ru)"
      skipped_count += 1
    end
  end
end

puts "\n📊 Статистика Telegram шаблонов:"
puts "  Создано: #{created_count}"
puts "  Обновлено: #{updated_count}"
puts "  Без изменений: #{skipped_count}"
puts "  Всего в БД: #{EmailTemplate.telegram_templates.count}"

# Тестируем один из созданных шаблонов
if EmailTemplate.telegram_templates.any?
  test_template = EmailTemplate.telegram_templates.first
  puts "\n🧪 Тестирование шаблона: #{test_template.name}"
  
  test_vars = {
    'booking_date' => '25.01.2025',
    'start_time' => '10:00',
    'service_point_address' => 'ул. Тестовая, 123',
    'service_category_name' => 'Замена шин',
    'client_first_name' => 'Иван'
  }
  
  begin
    rendered = test_template.render_telegram_template(test_vars)
    puts "  ✅ Рендеринг успешен"
    puts "  📱 Сообщение: #{rendered[:message][0..80]}..."
  rescue => e
    puts "  ❌ Ошибка рендеринга: #{e.message}"
  end
end

puts "✅ Telegram шаблоны готовы к использованию!" 