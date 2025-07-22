# Telegram Templates Seeds
# Создание шаблонов уведомлений для Telegram канала

puts "📱 Создание Telegram шаблонов уведомлений..."

# Telegram шаблоны на украинском языке
telegram_templates_uk = [
  {
    name: 'Підтвердження запису',
    template_type: 'booking_confirmation',
    language: 'uk',
    channel_type: 'telegram',
    subject: nil, # Telegram не использует subject
    body: '✅ Ваш запис підтверджено!

📅 Дата: {booking_date}
🕐 Час: {start_time}
📍 Адреса: {service_point_address}
🚗 Послуга: {service_name}

Очікуємо вас!',
    description: 'Telegram уведомление о подтверждении бронирования на украинском языке',
    variables: %w[booking_id booking_number booking_date start_time service_name service_point_name service_point_address city_name client_first_name client_last_name car_brand car_model license_plate],
    is_active: true
  },
  {
    name: 'Скасування запису',
    template_type: 'booking_cancelled',
    language: 'uk',
    channel_type: 'telegram',
    subject: nil,
    body: '❌ Ваш запис скасовано

📅 Дата: {booking_date}
🕐 Час: {start_time}
📍 Адреса: {service_point_address}

💬 Причина: Скасування адміністратором

Ви можете створити новий запис на сайті.',
    description: 'Telegram уведомление об отмене бронирования на украинском языке',
    variables: %w[booking_id booking_number booking_date start_time service_name service_point_name service_point_address city_name],
    is_active: true
  },
  {
    name: 'Нагадування про запис',
    template_type: 'booking_reminder',
    language: 'uk',
    channel_type: 'telegram',
    subject: nil,
    body: '⏰ Нагадуємо про ваш запис завтра!

📅 Дата: {booking_date}
🕐 Час: {start_time}
📍 Адреса: {service_point_address}
🚗 Послуга: {service_name}

Не забудьте прийти вчасно!',
    description: 'Telegram уведомление-напоминание о записи на украинском языке',
    variables: %w[booking_id booking_number booking_date start_time service_name service_point_name service_point_address city_name client_first_name],
    is_active: true
  },
  {
    name: 'Завершення обслуговування',
    template_type: 'service_completed',
    language: 'uk',
    channel_type: 'telegram',
    subject: nil,
    body: '✅ Обслуговування завершено!

📅 Дата: {booking_date}
🏢 {service_point_name}
🚗 {service_name}

Дякуємо за вибір Tire Service! 🚗✨

⭐ Будемо вдячні за ваш відгук!',
    description: 'Telegram уведомление о завершении обслуживания на украинском языке',
    variables: %w[booking_id booking_number booking_date service_name service_point_name city_name client_first_name],
    is_active: true
  },
  {
    name: 'Запит відгуку',
    template_type: 'review_request',
    language: 'uk',
    channel_type: 'telegram',
    subject: nil,
    body: '⭐ Як вам наше обслуговування?

📅 Дата: {booking_date}
🏢 {service_point_name}
🚗 {service_name}

Залиште відгук на сайті!',
    description: 'Telegram уведомление с просьбой оставить отзыв на украинском языке',
    variables: %w[booking_id booking_number booking_date service_name service_point_name city_name client_first_name],
    is_active: true
  },
  {
    name: 'Інформаційна розсилка',
    template_type: 'newsletter',
    language: 'uk',
    channel_type: 'telegram',
    subject: nil,
    body: '📢 {newsletter_title}

{newsletter_content}

🚗 З повагою,
Команда Tire Service',
    description: 'Telegram уведомление для информационной рассылки на украинском языке',
    variables: %w[newsletter_title newsletter_content],
    is_active: true
  }
]

# Telegram шаблоны на русском языке
telegram_templates_ru = [
  {
    name: 'Подтверждение записи',
    template_type: 'booking_confirmation',
    language: 'ru',
    channel_type: 'telegram',
    subject: nil,
    body: '✅ Ваша запись подтверждена!

📅 Дата: {booking_date}
🕐 Время: {start_time}
📍 Адрес: {service_point_address}
🚗 Услуга: {service_name}

Ожидаем вас!',
    description: 'Telegram уведомление о подтверждении бронирования на русском языке',
    variables: %w[booking_id booking_number booking_date start_time service_name service_point_name service_point_address city_name client_first_name client_last_name car_brand car_model license_plate],
    is_active: true
  },
  {
    name: 'Отмена записи',
    template_type: 'booking_cancelled',
    language: 'ru',
    channel_type: 'telegram',
    subject: nil,
    body: '❌ Ваша запись отменена

📅 Дата: {booking_date}
🕐 Время: {start_time}
📍 Адрес: {service_point_address}

💬 Причина: Отмена администратором

Вы можете создать новую запись на сайте.',
    description: 'Telegram уведомление об отмене бронирования на русском языке',
    variables: %w[booking_id booking_number booking_date start_time service_name service_point_name service_point_address city_name],
    is_active: true
  },
  {
    name: 'Напоминание о записи',
    template_type: 'booking_reminder',
    language: 'ru',
    channel_type: 'telegram',
    subject: nil,
    body: '⏰ Напоминаем о вашей записи завтра!

📅 Дата: {booking_date}
🕐 Время: {start_time}
📍 Адрес: {service_point_address}
🚗 Услуга: {service_name}

Не забудьте прийти вовремя!',
    description: 'Telegram уведомление-напоминание о записи на русском языке',
    variables: %w[booking_id booking_number booking_date start_time service_name service_point_name service_point_address city_name client_first_name],
    is_active: true
  },
  {
    name: 'Завершение обслуживания',
    template_type: 'service_completed',
    language: 'ru',
    channel_type: 'telegram',
    subject: nil,
    body: '✅ Обслуживание завершено!

📅 Дата: {booking_date}
🏢 {service_point_name}
🚗 {service_name}

Спасибо за выбор Tire Service! 🚗✨

⭐ Будем благодарны за ваш отзыв!',
    description: 'Telegram уведомление о завершении обслуживания на русском языке',
    variables: %w[booking_id booking_number booking_date service_name service_point_name city_name client_first_name],
    is_active: true
  },
  {
    name: 'Запрос отзыва',
    template_type: 'review_request',
    language: 'ru',
    channel_type: 'telegram',
    subject: nil,
    body: '⭐ Как вам наше обслуживание?

📅 Дата: {booking_date}
🏢 {service_point_name}
🚗 {service_name}

Оставьте отзыв на сайте!',
    description: 'Telegram уведомление с просьбой оставить отзыв на русском языке',
    variables: %w[booking_id booking_number booking_date service_name service_point_name city_name client_first_name],
    is_active: true
  },
  {
    name: 'Информационная рассылка',
    template_type: 'newsletter',
    language: 'ru',
    channel_type: 'telegram',
    subject: nil,
    body: '📢 {newsletter_title}

{newsletter_content}

🚗 С уважением,
Команда Tire Service',
    description: 'Telegram уведомление для информационной рассылки на русском языке',
    variables: %w[newsletter_title newsletter_content],
    is_active: true
  }
]

# Создаем украинские шаблоны
telegram_templates_uk.each do |template_data|
  template = EmailTemplate.find_or_initialize_by(
    template_type: template_data[:template_type],
    language: template_data[:language],
    channel_type: template_data[:channel_type]
  )
  
  template.assign_attributes(template_data)
  
  if template.save
    puts "  ✅ Telegram шаблон создан: #{template.name}"
  else
    puts "  ❌ Ошибка создания Telegram шаблона: #{template.name} - #{template.errors.full_messages.join(', ')}"
  end
end

# Создаем русские шаблоны
telegram_templates_ru.each do |template_data|
  template = EmailTemplate.find_or_initialize_by(
    template_type: template_data[:template_type],
    language: template_data[:language],
    channel_type: template_data[:channel_type]
  )
  
  template.assign_attributes(template_data)
  
  if template.save
    puts "  ✅ Telegram шаблон создан: #{template.name}"
  else
    puts "  ❌ Ошибка создания Telegram шаблона: #{template.name} - #{template.errors.full_messages.join(', ')}"
  end
end

puts "📱 Telegram шаблоны созданы: #{EmailTemplate.where(channel_type: 'telegram').count} шаблонов" 