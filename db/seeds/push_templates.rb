puts "🔔 Создание Push шаблонов уведомлений..."

# Push шаблоны на украинском языке
push_templates_uk = [
  {
    name: 'Підтвердження запису (Push)',
    template_type: 'booking_confirmation',
    language: 'uk',
    channel_type: 'push',
    subject: 'Запис підтверджено!',
    body: '📅 {booking_date} о {start_time}
🏢 {service_point_name}
📍 {service_point_address}
🚗 {service_name}

Очікуємо вас у призначений час!',
    description: 'Push уведомление о подтверждении бронирования на украинском языке',
    variables: %w[booking_id booking_number booking_date start_time service_name service_point_name service_point_address city_name client_first_name client_last_name car_brand car_model license_plate],
    is_active: true
  },
  {
    name: 'Скасування запису (Push)',
    template_type: 'booking_cancelled',
    language: 'uk',
    channel_type: 'push',
    subject: 'Запис скасовано',
    body: '📅 {booking_date} о {start_time}
🏢 {service_point_name}
🚗 {service_name}

Ви можете створити новий запис на сайті.',
    description: 'Push уведомление об отмене бронирования на украинском языке',
    variables: %w[booking_id booking_number booking_date start_time service_name service_point_name service_point_address city_name],
    is_active: true
  },
  {
    name: 'Нагадування про запис (Push)',
    template_type: 'booking_reminder',
    language: 'uk',
    channel_type: 'push',
    subject: 'Нагадування про запис',
    body: '⏰ Завтра у вас запис:

📅 {booking_date} о {start_time}
🏢 {service_point_name}
📍 {service_point_address}
🚗 {service_name}

Не забудьте прийти вчасно!',
    description: 'Push уведомление-напоминание о записи на украинском языке',
    variables: %w[booking_id booking_number booking_date start_time service_name service_point_name service_point_address city_name client_first_name],
    is_active: true
  },
  {
    name: 'Завершення обслуговування (Push)',
    template_type: 'service_completed',
    language: 'uk',
    channel_type: 'push',
    subject: 'Обслуговування завершено!',
    body: '✅ Ваше обслуговування завершено!

📅 {booking_date}
🏢 {service_point_name}
🚗 {service_name}

Дякуємо за вибір Tire Service! 🚗✨',
    description: 'Push уведомление о завершении обслуживания на украинском языке',
    variables: %w[booking_id booking_number booking_date service_name service_point_name city_name client_first_name],
    is_active: true
  },
  {
    name: 'Запит відгуку (Push)',
    template_type: 'review_request',
    language: 'uk',
    channel_type: 'push',
    subject: 'Оцініть наш сервіс!',
    body: '⭐ Як вам наше обслуговування?

📅 {booking_date}
🏢 {service_point_name}
🚗 {service_name}

Залиште відгук на сайті!',
    description: 'Push уведомление с просьбой оставить отзыв на украинском языке',
    variables: %w[booking_id booking_number booking_date service_name service_point_name city_name client_first_name],
    is_active: true
  }
]

# Push шаблоны на русском языке
push_templates_ru = [
  {
    name: 'Подтверждение записи (Push)',
    template_type: 'booking_confirmation',
    language: 'ru',
    channel_type: 'push',
    subject: 'Запись подтверждена!',
    body: '📅 {booking_date} в {start_time}
🏢 {service_point_name}
📍 {service_point_address}
🚗 {service_name}

Ждем вас в назначенное время!',
    description: 'Push уведомление о подтверждении бронирования на русском языке',
    variables: %w[booking_id booking_number booking_date start_time service_name service_point_name service_point_address city_name client_first_name client_last_name car_brand car_model license_plate],
    is_active: true
  },
  {
    name: 'Отмена записи (Push)',
    template_type: 'booking_cancelled',
    language: 'ru',
    channel_type: 'push',
    subject: 'Запись отменена',
    body: '📅 {booking_date} в {start_time}
🏢 {service_point_name}
🚗 {service_name}

Вы можете создать новую запись на сайте.',
    description: 'Push уведомление об отмене бронирования на русском языке',
    variables: %w[booking_id booking_number booking_date start_time service_name service_point_name service_point_address city_name],
    is_active: true
  },
  {
    name: 'Напоминание о записи (Push)',
    template_type: 'booking_reminder',
    language: 'ru',
    channel_type: 'push',
    subject: 'Напоминание о записи',
    body: '⏰ Завтра у вас запись:

📅 {booking_date} в {start_time}
🏢 {service_point_name}
📍 {service_point_address}
🚗 {service_name}

Не забудьте прийти вовремя!',
    description: 'Push уведомление-напоминание о записи на русском языке',
    variables: %w[booking_id booking_number booking_date start_time service_name service_point_name service_point_address city_name client_first_name],
    is_active: true
  },
  {
    name: 'Завершение обслуживания (Push)',
    template_type: 'service_completed',
    language: 'ru',
    channel_type: 'push',
    subject: 'Обслуживание завершено!',
    body: '✅ Ваше обслуживание завершено!

📅 {booking_date}
🏢 {service_point_name}
🚗 {service_name}

Спасибо за выбор Tire Service! 🚗✨',
    description: 'Push уведомление о завершении обслуживания на русском языке',
    variables: %w[booking_id booking_number booking_date service_name service_point_name city_name client_first_name],
    is_active: true
  },
  {
    name: 'Запрос отзыва (Push)',
    template_type: 'review_request',
    language: 'ru',
    channel_type: 'push',
    subject: 'Оцените наш сервис!',
    body: '⭐ Как вам наше обслуживание?

📅 {booking_date}
🏢 {service_point_name}
🚗 {service_name}

Оставьте отзыв на сайте!',
    description: 'Push уведомление с просьбой оставить отзыв на русском языке',
    variables: %w[booking_id booking_number booking_date service_name service_point_name city_name client_first_name],
    is_active: true
  }
]

# Создаем украинские шаблоны
push_templates_uk.each do |template_data|
  template = EmailTemplate.find_or_initialize_by(
    template_type: template_data[:template_type],
    language: template_data[:language],
    channel_type: template_data[:channel_type]
  )
  
  template.assign_attributes(template_data)
  
  if template.save
    puts "  ✅ Push шаблон создан: #{template.name}"
  else
    puts "  ❌ Ошибка создания Push шаблона: #{template.name} - #{template.errors.full_messages.join(', ')}"
  end
end

# Создаем русские шаблоны
push_templates_ru.each do |template_data|
  template = EmailTemplate.find_or_initialize_by(
    template_type: template_data[:template_type],
    language: template_data[:language],
    channel_type: template_data[:channel_type]
  )
  
  template.assign_attributes(template_data)
  
  if template.save
    puts "  ✅ Push шаблон создан: #{template.name}"
  else
    puts "  ❌ Ошибка создания Push шаблона: #{template.name} - #{template.errors.full_messages.join(', ')}"
  end
end

puts "🔔 Push шаблоны созданы: #{EmailTemplate.where(channel_type: 'push').count} шаблонов" 