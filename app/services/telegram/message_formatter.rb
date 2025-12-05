# frozen_string_literal: true

module Telegram
  # MessageFormatter - форматирование сообщений для Telegram
  # Отвечает за: шаблоны уведомлений, клавиатуры, форматирование
  class MessageFormatter
    # Форматирование уведомления о бронировании
    # @param booking [Booking] объект бронирования
    # @param type [String] тип уведомления
    # @param language [String] язык (uk, ru)
    # @return [String] отформатированное сообщение
    def format_booking_notification(booking, type, language = 'uk')
      # Пытаемся найти шаблон в БД
      template = find_template(type, language)

      if template
        Rails.logger.info "📧 Telegram::MessageFormatter: Используем шаблон из БД: #{template.name}"
        variables = prepare_booking_variables(booking)
        rendered = template.render_with_variables(variables)
        rendered[:body]
      else
        Rails.logger.warn "⚠️ Telegram::MessageFormatter: Шаблон не найден (#{type}, #{language}), используем fallback"
        format_booking_fallback(booking, type)
      end
    end

    # === Клавиатуры ===

    def build_cities_keyboard(cities)
      buttons = cities.map do |city|
        [{ text: city.name, callback_data: "booking_city_#{city.id}" }]
      end
      { inline_keyboard: buttons }
    end

    def build_service_categories_keyboard(categories)
      buttons = categories.map do |category|
        [{ text: category.name, callback_data: "booking_service_#{category.id}" }]
      end
      { inline_keyboard: buttons }
    end

    def build_service_points_keyboard(service_points)
      buttons = service_points.map do |point|
        address = point.address.present? ? " (#{point.address})" : ''
        [{ text: "#{point.name}#{address}", callback_data: "booking_point_#{point.id}" }]
      end
      { inline_keyboard: buttons }
    end

    def build_calendar_keyboard(days_count: 14)
      buttons = []
      start_date = Date.current + 1.day

      (0...days_count).each do |day_offset|
        date = start_date + day_offset.days
        next if date.sunday?

        day_name = I18n.l(date, format: '%A, %d.%m', locale: :ru)
        buttons << [{ text: day_name, callback_data: "booking_date_#{date.strftime('%Y-%m-%d')}" }]
      end

      { inline_keyboard: buttons }
    end

    def build_time_slots_keyboard(time_slots)
      buttons = time_slots.map do |time|
        [{ text: time, callback_data: "booking_time_#{time}" }]
      end
      { inline_keyboard: buttons }
    end

    def build_car_types_keyboard(car_types)
      buttons = car_types.map do |car_type|
        [{ text: car_type.name, callback_data: "booking_car_type_#{car_type.id}" }]
      end
      { inline_keyboard: buttons }
    end

    def build_phone_request_keyboard
      {
        keyboard: [
          [{ text: '📞 Отправить контакт', request_contact: true }]
        ],
        resize_keyboard: true,
        one_time_keyboard: true
      }
    end

    def build_confirmation_keyboard
      {
        inline_keyboard: [
          [
            { text: '✅ Подтвердить', callback_data: 'booking_confirm' },
            { text: '❌ Отменить', callback_data: 'booking_cancel' }
          ]
        ]
      }
    end

    def build_skip_keyboard
      {
        inline_keyboard: [
          [{ text: '⏭️ Пропустить', callback_data: 'booking_skip_comment' }]
        ]
      }
    end

    def build_main_menu_keyboard
      {
        inline_keyboard: [
          [{ text: '📅 Створити бронювання', callback_data: 'start_booking' }],
          [{ text: '🌐 Відкрити сайт', url: ENV.fetch('FRONTEND_URL', 'http://localhost:3008') }],
          [{ text: '⚙️ Налаштування', callback_data: 'settings' }]
        ]
      }
    end

    def build_settings_keyboard
      {
        inline_keyboard: [
          [{ text: '🔔 Бронирования', callback_data: 'toggle_booking' }],
          [{ text: '🎉 Акции', callback_data: 'toggle_promotion' }],
          [{ text: '⏰ Напоминания', callback_data: 'toggle_reminder' }],
          [{ text: '🌍 Язык', callback_data: 'change_language' }]
        ]
      }
    end

    def remove_keyboard
      { remove_keyboard: true }
    end

    private

    def find_template(type, language)
      EmailTemplate.where(
        template_type: type,
        language: language,
        channel_type: 'telegram',
        is_active: true
      ).first
    end

    def prepare_booking_variables(booking)
      service_name = if booking.services.any?
                       booking.services.first.name
                     elsif booking.respond_to?(:service_category) && booking.service_category
                       booking.service_category.name
                     else
                       'Послуга шиномонтажу'
                     end

      point_name = booking.service_point&.name || 'Сервісна точка'
      point_address = booking.service_point&.address || 'Адреса не вказана'
      city_name = booking.service_point&.city&.name || 'Місто не вказано'
      date = booking.start_time&.strftime('%d.%m.%Y') || booking.booking_date&.strftime('%d.%m.%Y') || 'Не вказано'
      time = booking.start_time&.strftime('%H:%M') || 'Не вказано'
      client_phone = booking.client&.user&.phone || booking.service_recipient_phone || 'Не вказано'

      {
        'booking_id' => booking.id.to_s,
        'booking_number' => "##{booking.id}",
        'booking_date' => date,
        'start_time' => time,
        'end_time' => booking.end_time&.strftime('%H:%M') || '',
        'service_name' => service_name,
        'service_point_name' => point_name,
        'service_point_address' => point_address,
        'city_name' => city_name,
        'client_first_name' => booking.service_recipient_first_name || '',
        'client_last_name' => booking.service_recipient_last_name || '',
        'client_phone' => client_phone,
        'client_email' => booking.service_recipient_email || '',
        'car_brand' => booking.car_brand || 'Не вказана',
        'car_model' => booking.car_model || 'Не вказана',
        'license_plate' => booking.license_plate || 'Не вказано',
        'status' => booking.status || 'pending',
        'notes' => booking.notes || ''
      }
    end

    def format_booking_fallback(booking, type)
      service_name = booking.services.first&.name || 'Невідома послуга'
      point_name = booking.service_point&.name || 'Невідома точка'
      date = booking.start_time&.strftime('%d.%m.%Y о %H:%M') || 'Не вказано'

      case type
      when 'booking_confirmation'
        "🎉 <b>Нове бронювання створено!</b>\n\n" \
        "🔧 <b>Послуга:</b> #{service_name}\n" \
        "📍 <b>Сервісна точка:</b> #{point_name}\n" \
        "📅 <b>Дата та час:</b> #{date}\n\n" \
        "Ми зв'яжемося з вами для підтвердження."
      when 'booking_cancelled'
        "❌ <b>Бронювання скасовано</b>\n\n" \
        "🔧 <b>Послуга:</b> #{service_name}\n" \
        "📍 <b>Сервісна точка:</b> #{point_name}\n" \
        "📅 <b>Дата та час:</b> #{date}\n\n" \
        "Ви можете створити нове бронювання на сайті."
      when 'booking_reminder'
        "⏰ <b>Нагадування про візит</b>\n\n" \
        "Завтра у вас заплановано:\n" \
        "🔧 <b>Послуга:</b> #{service_name}\n" \
        "📍 <b>Сервісна точка:</b> #{point_name}\n" \
        "📅 <b>Час:</b> #{date}\n\n" \
        "Не забудьте прийти вчасно!"
      when 'service_completed'
        "✅ <b>Послуга виконана!</b>\n\n" \
        "🔧 <b>Послуга:</b> #{service_name}\n" \
        "📍 <b>Сервісна точка:</b> #{point_name}\n" \
        "📅 <b>Дата:</b> #{date}\n\n" \
        'Дякуємо за вибір Tire Service! 🚗'
      when 'review_request'
        "⭐ <b>Оцініть наш сервіс!</b>\n\n" \
        "🔧 <b>Послуга:</b> #{service_name}\n" \
        "📍 <b>Сервісна точка:</b> #{point_name}\n" \
        "📅 <b>Дата:</b> #{date}\n\n" \
        'Будемо вдячні за ваш відгук на сайті!'
      else
        "📋 <b>Оновлення бронювання</b>\n\n" \
        "🔧 <b>Послуга:</b> #{service_name}\n" \
        "📍 <b>Сервісна точка:</b> #{point_name}\n" \
        "📅 <b>Дата та час:</b> #{date}"
      end
    end
  end
end
