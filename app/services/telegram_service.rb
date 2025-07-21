require 'httparty'
require 'securerandom'
require 'stringio'

class TelegramService
  include HTTParty
  
  base_uri 'https://api.telegram.org'
  
  def initialize
    # Получаем настройки из БД или переменных окружения
    settings = TelegramSetting.current
    @token = settings.effective_bot_token
    
    unless @token.present?
      Rails.logger.error "❌ TELEGRAM_BOT_TOKEN не установлен ни в БД, ни в ENV"
      raise 'TELEGRAM_BOT_TOKEN не установлен'
    end
    
    Rails.logger.info "✅ TelegramService инициализирован с токеном: #{@token[0..10]}..."
  end

  # Отправка сообщения с поддержкой клавиатур
  def send_message(chat_id, message, keyboard = nil, parse_mode = 'HTML')
    Rails.logger.info "🚀 TelegramService: Отправляем сообщение в chat_id: #{chat_id}"
    Rails.logger.info "📝 TelegramService: Текст сообщения: #{message}"
    
    params = {
      chat_id: chat_id,
      text: message,
      parse_mode: parse_mode,
      disable_web_page_preview: true
    }
    
    # Добавляем inline клавиатуру если есть
    if keyboard.present?
      params[:reply_markup] = keyboard.to_json
    end
    
    Rails.logger.info "📦 TelegramService: Параметры запроса: #{params}"
    
    begin
      response = self.class.post("/bot#{@token}/sendMessage", body: params)
      Rails.logger.info "📡 TelegramService: Ответ от Telegram API: #{response.code} - #{response.body}"
      result = handle_response(response)
      Rails.logger.info "✅ TelegramService: Результат обработки: #{result}"
      result
    rescue => e
      Rails.logger.error "❌ TelegramService: Ошибка отправки: #{e.message}"
      Rails.logger.error "❌ TelegramService: Backtrace: #{e.backtrace.first(5).join('\n')}"
      raise e
    end
  end

  # Редактирование сообщения
  def edit_message(chat_id, message_id, text, keyboard = nil, parse_mode = 'HTML')
    Rails.logger.info "✏️ TelegramService: Редактируем сообщение #{message_id} в chat_id: #{chat_id}"
    
    params = {
      chat_id: chat_id,
      message_id: message_id,
      text: text,
      parse_mode: parse_mode,
      disable_web_page_preview: true
    }
    
    # Добавляем inline клавиатуру если есть
    if keyboard.present?
      params[:reply_markup] = keyboard.to_json
    end
    
    begin
      response = self.class.post("/bot#{@token}/editMessageText", body: params)
      Rails.logger.info "📡 TelegramService: Ответ от Telegram API (edit): #{response.code} - #{response.body}"
      handle_response(response)
    rescue => e
      Rails.logger.error "❌ TelegramService: Ошибка редактирования: #{e.message}"
      # Если не удалось отредактировать, отправляем новое сообщение
      send_message(chat_id, text, keyboard, parse_mode)
    end
  end

  # Ответ на callback query
  def answer_callback_query(callback_query_id, text = nil, show_alert = false)
    params = {
      callback_query_id: callback_query_id
    }
    
    params[:text] = text if text.present?
    params[:show_alert] = show_alert if show_alert
    
    response = self.class.post("/bot#{@token}/answerCallbackQuery", body: params)
    handle_response(response)
  end

  # Получение информации о боте
  def get_me
    response = self.class.get("/bot#{@token}/getMe")
    handle_response(response)
  end

  # Получение информации о пользователе
  def get_chat(chat_id)
    response = self.class.get("/bot#{@token}/getChat", query: { chat_id: chat_id })
    handle_response(response)
  end

  # Получение обновлений (для webhook)
  def get_updates(offset = nil)
    params = {}
    params[:offset] = offset if offset
    
    response = self.class.get("/bot#{@token}/getUpdates", query: params)
    handle_response(response)
  end

  # Установка webhook
  def set_webhook(webhook_url)
    Rails.logger.info "🔗 Устанавливаем webhook: #{webhook_url}"
    
    params = {
      url: webhook_url
    }
    
    response = self.class.post("/bot#{@token}/setWebhook", body: params)
    result = handle_response(response)
    
    if result[:ok]
      Rails.logger.info "✅ Webhook успешно установлен"
    else
      Rails.logger.error "❌ Ошибка установки webhook: #{result[:description]}"
    end
    
    result
  end

  # Удаление webhook
  def delete_webhook
    Rails.logger.info "🗑️ Удаляем webhook"
    
    response = self.class.post("/bot#{@token}/deleteWebhook")
    result = handle_response(response)
    
    if result[:ok]
      Rails.logger.info "✅ Webhook успешно удален"
    else
      Rails.logger.error "❌ Ошибка удаления webhook: #{result[:description]}"
    end
    
    result
  end

  # Получение информации о webhook
  def get_webhook_info
    response = self.class.get("/bot#{@token}/getWebhookInfo")
    handle_response(response)
  end

  # Отправка уведомления с сохранением в БД
  def send_notification(user, message, options = {})
    return false unless user.telegram_subscription&.can_receive_notifications?

    subscription = user.telegram_subscription
    return false unless subscription

    # Создаем запись уведомления
    notification = TelegramNotification.create!(
      user: user,
      message: message,
      chat_id: subscription.chat_id,
      notification_type: options[:type] || 'general',
      booking: options[:booking]
    )

    begin
      # Отправляем сообщение
      response = send_message(subscription.chat_id, message, options[:keyboard])
      
      if response[:ok]
        notification.mark_as_sent!(response, response[:result][:message_id])
        subscription.update_last_interaction!
        
        Rails.logger.info "Telegram сповіщення надіслано користувачу #{user.id}"
        true
      else
        notification.mark_as_failed!(response[:description])
        
        Rails.logger.error "Помилка відправки Telegram сповіщення: #{response[:description]}"
        false
      end
    rescue => e
      notification.mark_as_failed!(e.message)
      Rails.logger.error "Виняток при відправці Telegram сповіщення: #{e.message}"
      false
    end
  end

  # Массовая отправка уведомлений
  def send_bulk_notification(users, message, options = {})
    results = {
      total: users.count,
      sent: 0,
      failed: 0,
      details: []
    }

    users.each do |user|
      begin
        if send_notification(user, message, options)
          results[:sent] += 1
          results[:details] << { user_id: user.id, status: 'sent' }
        else
          results[:failed] += 1
          results[:details] << { user_id: user.id, status: 'failed', error: 'Не вдалося надіслати' }
        end
      rescue => e
        results[:failed] += 1
        results[:details] << { user_id: user.id, status: 'failed', error: e.message }
      end
    end

    Rails.logger.info "Масова розсилка завершена: #{results[:sent]} надіслано, #{results[:failed]} помилок"
    results
  end

  # Повторная отправка неудачных уведомлений
  def retry_failed_notifications
    failed_notifications = TelegramNotification.failed.where('created_at > ?', 24.hours.ago)
    retried_count = 0

    failed_notifications.each do |notification|
      if notification.can_retry?
        if send_notification(notification.user, notification.message, { 
          type: notification.notification_type,
          booking: notification.booking 
        })
          retried_count += 1
        end
      end
    end

    Rails.logger.info "Повторно надіслано #{retried_count} сповіщень"
    retried_count
  end

  # Обработка команд бота
  def handle_command(chat_id, command, user_data = {})
    case command
    when '/start'
      handle_start_command(chat_id, user_data)
    when '/stop'
      handle_stop_command(chat_id)
    when '/help'
      handle_help_command(chat_id)
    when '/status'
      handle_status_command(chat_id)
    when '/settings'
      handle_settings_command(chat_id)
    when '/booking'
      handle_booking_command(chat_id)
    else
      # Проверяем, есть ли активная сессия бронирования
      session = TelegramBookingSession.active.find_by(chat_id: chat_id)
      if session
        handle_booking_step(chat_id, command, session)
    else
      send_message(chat_id, "❓ Неизвестная команда. Используйте /help для получения списка команд.")
    end
    end
  end

  # Обработка callback query для inline клавиатур
  def handle_callback_query(chat_id, callback_data, message_id = nil, user_data = {})
    Rails.logger.info "🔄 TelegramService: Обработка callback_query: #{callback_data}"
    
    # Проверяем, есть ли активная сессия бронирования
    session = TelegramBookingSession.active.find_by(chat_id: chat_id)
    
    if session && callback_data.start_with?('booking_')
      handle_booking_callback(chat_id, callback_data, message_id, session)
    else
      handle_settings_callback(chat_id, callback_data, message_id)
    end
  end

  # Новая команда для начала бронирования
  def handle_booking_command(chat_id)
    # Проверяем, есть ли уже активная сессия
    existing_session = TelegramBookingSession.active.find_by(chat_id: chat_id)
    existing_session&.destroy
    
    # Создаем новую сессию бронирования
    session = TelegramBookingSession.create!(
      chat_id: chat_id,
      current_step: TelegramBookingSession::BOOKING_STEPS[:city_selection],
      expires_at: 1.hour.from_now
    )
    
    start_city_selection(chat_id, session)
  end

  # Шаг 1: Выбор города
  def start_city_selection(chat_id, session)
    message = "🏙️ <b>Шаг 1/8: Выберите город</b>\n\n" \
              "Выберите город, где хотите записаться на обслуживание:"

    # Получаем список городов с сервисными точками
    cities = City.joins(:service_points)
                .where(service_points: { work_status: 'working', is_active: true })
                .distinct
                .order(:name)

    keyboard = build_cities_keyboard(cities)
    send_message(chat_id, message, keyboard)
  end

  # Шаг 2: Выбор услуги
  def start_service_selection(chat_id, session)
    city_id = session.get_data(:city_id)
    city = City.find(city_id)
    
    message = "🔧 <b>Шаг 2/8: Выберите тип услуги</b>\n\n" \
              "Доступные услуги в городе <b>#{city.name}</b>:"

    # Получаем категории услуг, доступные в выбранном городе
    categories = get_service_categories_by_city(city_id)
    
    if categories.empty?
      send_message(chat_id, "❌ В городе #{city.name} пока нет доступных услуг.")
      return
    end
    
    keyboard = build_service_categories_keyboard(categories)
    send_message(chat_id, message, keyboard)
  end

  # Шаг 3: Выбор сервисного центра
  def start_service_point_selection(chat_id, session)
    city_id = session.get_data(:city_id)
    service_category_id = session.get_data(:service_category_id)
    city = City.find(city_id)
    service_category = ServiceCategory.find(service_category_id)
    
    message = "📍 <b>Шаг 3/8: Выберите сервисный центр</b>\n\n" \
              "Доступные центры в городе <b>#{city.name}</b>\n" \
              "для услуги <b>#{service_category.name}</b>:"

    # Получаем сервисные точки с активными постами выбранной категории
    service_points = get_service_points_by_category(service_category_id, city_id)
    
    if service_points.empty?
      send_message(chat_id, "❌ В городе #{city.name} нет доступных центров для услуги \"#{service_category.name}\".")
      return
    end
    
    keyboard = build_service_points_keyboard(service_points)
    send_message(chat_id, message, keyboard)
  end

  # Шаг 4: Выбор даты и времени
  def start_datetime_selection(chat_id, session)
    message = "📅 <b>Шаг 4/8: Выберите дату</b>\n\n" \
              "Выберите удобную дату для записи:"

    # Генерируем календарь на ближайшие 14 дней
    keyboard = build_calendar_keyboard
    send_message(chat_id, message, keyboard)
  end

  # Шаг 5: Выбор типа автомобиля
  def start_car_type_selection(chat_id, session)
    message = "🚗 <b>Шаг 5/8: Выберите тип автомобиля</b>\n\n" \
              "Укажите тип вашего автомобиля:"

    car_types = CarType.active.order(:name)
    keyboard = build_car_types_keyboard(car_types)
    
    send_message(chat_id, message, keyboard)
  end

  # Шаг 6: Ввод номера телефона
  def start_phone_input(chat_id, session)
    message = "📱 <b>Шаг 6/8: Укажите номер телефона</b>\n\n" \
              "Введите ваш номер телефона в формате +380XXXXXXXXX\n" \
              "Например: +380671234567"

    # Кнопка для отправки контакта
    keyboard = {
      keyboard: [
        [{ text: "📞 Отправить контакт", request_contact: true }]
      ],
      resize_keyboard: true,
      one_time_keyboard: true
    }

    send_message(chat_id, message, keyboard)
  end

  # Шаг 7: Ввод номера автомобиля
  def start_license_plate_input(chat_id, session)
    message = "🚙 <b>Шаг 7/8: Укажите номер автомобиля</b>\n\n" \
              "Введите государственный номер вашего автомобиля.\n" \
              "Например: AA1234BB"

    # Убираем клавиатуру
    keyboard = { remove_keyboard: true }
    send_message(chat_id, message, keyboard)
  end

  # Шаг 8: Ввод комментария (опционально)
  def start_comment_input(chat_id, session)
    message = "💬 <b>Шаг 8/8: Комментарий (опционально)</b>\n\n" \
              "Есть ли у вас дополнительные пожелания или комментарии?\n\n" \
              "Вы можете пропустить этот шаг, нажав кнопку \"Пропустить\"."

    keyboard = {
      inline_keyboard: [
        [{ text: "⏭️ Пропустить", callback_data: "booking_skip_comment" }]
      ]
    }

    send_message(chat_id, message, keyboard)
  end

  # Подтверждение бронирования
  def show_booking_confirmation(chat_id, session)
    booking_data = session.booking_data
    
    # Получаем данные для отображения
    city = City.find(booking_data[:city_id])
    service_category = ServiceCategory.find(booking_data[:service_category_id])
    service_point = ServicePoint.find(booking_data[:service_point_id])
    car_type = CarType.find(booking_data[:car_type_id])
    
    message = "✅ <b>Подтверждение бронирования</b>\n\n" \
              "📋 <b>Детали записи:</b>\n" \
              "🏙️ Город: #{city.name}\n" \
              "🔧 Услуга: #{service_category.name}\n" \
              "📍 Центр: #{service_point.name}\n" \
              "📅 Дата: #{booking_data[:date]}\n" \
              "⏰ Время: #{booking_data[:time]}\n" \
              "🚗 Тип авто: #{car_type.name}\n" \
              "📱 Телефон: #{booking_data[:phone]}\n" \
              "🚙 Номер: #{booking_data[:license_plate]}\n"
              
    if booking_data[:comment].present?
      message += "💬 Комментарий: #{booking_data[:comment]}\n"
    end
    
    message += "\n<b>Все данные верны?</b>"

    keyboard = {
      inline_keyboard: [
        [
          { text: "✅ Подтвердить", callback_data: "booking_confirm" },
          { text: "❌ Отменить", callback_data: "booking_cancel" }
        ]
      ]
    }

    send_message(chat_id, message, keyboard)
  end

  def handle_booking_step(chat_id, text, session)
    case session.current_step
    when 'phone_input'
      handle_phone_input(chat_id, text, session)
    when 'license_plate_input'
      handle_license_plate_input(chat_id, text, session)
    when 'comment_input'
      handle_comment_input(chat_id, text, session)
    else
      send_message(chat_id, "❓ Пожалуйста, используйте кнопки для выбора.")
    end
  end

  def handle_phone_input(chat_id, text, session)
    # Простая валидация номера телефона
    phone = text.gsub(/[^\d+]/, '')
    
    if phone.match?(/^\+380\d{9}$/)
      session.update_step('license_plate_input', { phone: phone })
      start_license_plate_input(chat_id, session)
    else
      send_message(chat_id, "❌ Неверный формат номера. Пожалуйста, введите номер в формате +380XXXXXXXXX")
    end
  end

  def handle_license_plate_input(chat_id, text, session)
    # Простая валидация номера авто - только непустое значение
    license_plate = text.strip
    
    if license_plate.present? && license_plate.length >= 1
      session.update_step('comment_input', { license_plate: license_plate })
      start_comment_input(chat_id, session)
    else
      send_message(chat_id, "❌ Пожалуйста, введите номер автомобиля.")
    end
  end

  def handle_comment_input(chat_id, text, session)
    comment = text.strip
    session.update_step('confirmation', { comment: comment })
    show_booking_confirmation(chat_id, session)
  end

  # Форматирование уведомления о бронировании
  def format_booking_notification(booking, type)
    service_name = booking.service_point_service&.service&.name || 'Невідома послуга'
    point_name = booking.service_point&.name || 'Невідома точка'
    date = booking.start_time&.strftime('%d.%m.%Y о %H:%M') || 'Не вказано'

    case type
    when 'booking_created'
      "🎉 <b>Нове бронювання створено!</b>\n\n" \
      "🔧 <b>Послуга:</b> #{service_name}\n" \
      "📍 <b>Сервісна точка:</b> #{point_name}\n" \
      "📅 <b>Дата та час:</b> #{date}\n\n" \
      "Ми зв'яжемося з вами для підтвердження."
    when 'booking_confirmed'
      "✅ <b>Бронювання підтверджено!</b>\n\n" \
      "🔧 <b>Послуга:</b> #{service_name}\n" \
      "📍 <b>Сервісна точка:</b> #{point_name}\n" \
      "📅 <b>Дата та час:</b> #{date}\n\n" \
      "Очікуємо на вас у призначений час!"
    when 'booking_reminder'
      "⏰ <b>Нагадування про візит</b>\n\n" \
      "Завтра у вас заплановано:\n" \
      "🔧 <b>Послуга:</b> #{service_name}\n" \
      "📍 <b>Сервісна точка:</b> #{point_name}\n" \
      "📅 <b>Час:</b> #{date}\n\n" \
      "Не забудьте прийти вчасно!"
    when 'booking_cancelled'
      "❌ <b>Бронювання скасовано</b>\n\n" \
      "🔧 <b>Послуга:</b> #{service_name}\n" \
      "📍 <b>Сервісна точка:</b> #{point_name}\n" \
      "📅 <b>Дата та час:</b> #{date}\n\n" \
      "Ви можете створити нове бронювання на сайті."
    when 'booking_completed'
      "✅ <b>Послуга виконана!</b>\n\n" \
      "🔧 <b>Послуга:</b> #{service_name}\n" \
      "📍 <b>Сервісна точка:</b> #{point_name}\n" \
      "📅 <b>Дата:</b> #{date}\n\n" \
      "Дякуємо за вибір Tire Service! 🚗"
    else
      "📋 <b>Оновлення бронювання</b>\n\n" \
      "🔧 <b>Послуга:</b> #{service_name}\n" \
      "📍 <b>Сервісна точка:</b> #{point_name}\n" \
      "📅 <b>Дата та час:</b> #{date}"
    end
  end

  def handle_booking_callback(chat_id, callback_data, message_id, session)
    case callback_data
    when /^booking_city_(\d+)$/
      city_id = $1.to_i
      session.update_step('service_selection', { city_id: city_id })
      start_service_selection(chat_id, session)
      
    when /^booking_service_(\d+)$/
      service_category_id = $1.to_i
      session.update_step('service_point_selection', { service_category_id: service_category_id })
      start_service_point_selection(chat_id, session)
      
    when /^booking_point_(\d+)$/
      service_point_id = $1.to_i
      session.update_step('datetime_selection', { service_point_id: service_point_id })
      start_datetime_selection(chat_id, session)
      
    when /^booking_date_(.+)$/
      date = $1
      session.update_step('datetime_selection', { date: date })
      start_time_selection(chat_id, session, date)
      
    when /^booking_time_(.+)$/
      time = $1
      # Сохраняем и время, и дату в booking_data
      current_date = session.get_data(:date)
      session.update_step('car_type_selection', { time: time, date: current_date })
      start_car_type_selection(chat_id, session)
      
    when /^booking_car_type_(\d+)$/
      car_type_id = $1.to_i
      session.update_step('phone_input', { car_type_id: car_type_id })
      start_phone_input(chat_id, session)
      
    when 'booking_skip_comment'
      session.update_step('confirmation', { comment: '' })
      show_booking_confirmation(chat_id, session)
      
    when 'booking_confirm'
      create_booking_from_session(chat_id, session)
      
    when 'booking_cancel'
      session.destroy
      send_message(chat_id, "❌ Бронирование отменено.")
    end
  end

  def start_time_selection(chat_id, session, date)
    service_point_id = session.get_data(:service_point_id)
    service_category_id = session.get_data(:service_category_id)
    
    message = "⏰ <b>Выберите время</b>\n\n" \
              "Доступное время на #{Date.parse(date).strftime('%d.%m.%Y')}:"

    begin
      # Используем тот же API что и веб-версия для получения реальных доступных слотов
      response = HTTParty.get(
        "http://localhost:8000/api/v1/availability/slots_for_category",
        query: {
          service_point_id: service_point_id,
          date: date,
          category_id: service_category_id
        },
        headers: { 'Content-Type' => 'application/json' }
      )
      
      if response.success? && response.parsed_response['slots']
        available_slots = response.parsed_response['slots']
        
        # Фильтруем только доступные слоты (available_posts > 0)
        time_slots = available_slots
          .select { |slot| (slot['available_posts'] || 0) > 0 }
          .map { |slot| slot['start_time'] }
          .uniq
          .sort
        
        if time_slots.empty?
          send_message(chat_id, "❌ На выбранную дату нет доступного времени. Попробуйте выбрать другую дату.")
          return
        end
        
        # Создаем кнопки из доступных слотов
        buttons = time_slots.map do |time|
          [{ text: time, callback_data: "booking_time_#{time}" }]
        end
        
        keyboard = { inline_keyboard: buttons }
        send_message(chat_id, message, keyboard)
      else
        Rails.logger.error "Error getting time slots: #{response.body}"
        send_message(chat_id, "❌ Ошибка при получении доступного времени. Попробуйте позже.")
      end
      
    rescue => e
      Rails.logger.error "Error in start_time_selection: #{e.message}\n#{e.backtrace.join("\n")}"
      send_message(chat_id, "❌ Ошибка при получении доступного времени. Попробуйте позже.")
    end
  end

  def create_booking_from_session(chat_id, session)
    booking_data = session.booking_data
    
    begin
      # Проверяем существующего пользователя по телефону
      phone = booking_data[:phone]
      user = User.find_by(phone: phone)
      
      if user
        # Существующий пользователь - создаем обычное бронирование
        client = user.client
        if client
          create_regular_booking(client, booking_data, session)
        else
          send_message(chat_id, "❌ Ошибка: пользователь не является клиентом.")
          return
        end
      else
        # Новый пользователь - создаем гостевое бронирование
        create_guest_booking(booking_data, session)
      end
      
      # Удаляем сессию после успешного создания
      session.destroy
      
    rescue => e
      Rails.logger.error "Ошибка создания бронирования: #{e.message}"
      send_message(chat_id, "❌ Произошла ошибка при создании бронирования. Попробуйте позже.")
    end
  end

  def create_regular_booking(client, booking_data, session)
    # Используем HTTP API для создания бронирования
    booking_payload = {
      booking: {
        service_point_id: booking_data[:service_point_id],
        service_category_id: booking_data[:service_category_id],
        car_type_id: booking_data[:car_type_id],
        booking_date: booking_data[:date],
        start_time: booking_data[:time],
        license_plate: booking_data[:license_plate],
        car_brand: "Не указана",
        car_model: "Не указана",
        notes: booking_data[:comment] || "",
        # Данные получателя услуги (клиент)
        service_recipient_first_name: client.user.first_name,
        service_recipient_last_name: client.user.last_name,
        service_recipient_phone: client.user.phone,
        service_recipient_email: client.user.email
      },
      client_id: client.id
    }
    
    begin
      # Отправляем HTTP POST запрос к API
      response = HTTParty.post(
        "http://localhost:8000/api/v1/client_bookings",
        headers: { 'Content-Type' => 'application/json' },
        body: booking_payload.to_json
      )
      
      if response.success?
        booking_response = JSON.parse(response.body)
        booking_id = booking_response['id']
        
        send_message(session.chat_id, "✅ <b>Бронирование успешно создано!</b>\n\n" \
                                     "📋 ID бронирования: #{booking_id}\n" \
                                     "📅 Дата: #{booking_data[:date]}\n" \
                                     "⏰ Время: #{booking_data[:time]}\n" \
                                     "🏢 Центр: #{ServicePoint.find(booking_data[:service_point_id]).name}\n\n" \
                                     "Вы получите уведомление о подтверждении.")
      else
        error_response = JSON.parse(response.body) rescue {}
        error_message = error_response['error'] || 'Неизвестная ошибка'
        
        Rails.logger.error "Booking creation failed: #{error_message}"
        send_message(session.chat_id, "❌ Ошибка создания бронирования: #{error_message}")
      end
      
    rescue => e
      Rails.logger.error "Error creating regular booking: #{e.message}\n#{e.backtrace.join("\n")}"
      send_message(session.chat_id, "❌ Произошла ошибка при создании бронирования. Попробуйте позже.")
    end
  end

  def create_guest_booking(booking_data, session)
    # Используем HTTP API для создания гостевого бронирования
    booking_payload = {
      booking: {
        service_point_id: booking_data[:service_point_id],
        service_category_id: booking_data[:service_category_id],
        car_type_id: booking_data[:car_type_id],
        booking_date: booking_data[:date],
        start_time: booking_data[:time],
        license_plate: booking_data[:license_plate],
        car_brand: "Не указана",
        car_model: "Не указана",
        notes: booking_data[:comment] || "",
        # Данные получателя услуги (гость)
        service_recipient_first_name: booking_data[:first_name] || "Гость",
        service_recipient_last_name: booking_data[:last_name] || "Telegram",
        service_recipient_phone: booking_data[:phone],
        service_recipient_email: "guest_telegram_#{SecureRandom.hex(4)}@tire-service.local"
      }
      # НЕ передаем client_id для гостевого бронирования
    }
    
    begin
      # Отправляем HTTP POST запрос к API
      response = HTTParty.post(
        "http://localhost:8000/api/v1/client_bookings",
        headers: { 'Content-Type' => 'application/json' },
        body: booking_payload.to_json
      )
      
      if response.success?
        booking_response = JSON.parse(response.body)
        booking_id = booking_response['id']
        
        send_message(session.chat_id, "✅ <b>Гостевое бронирование создано!</b>\n\n" \
                                     "📋 ID бронирования: #{booking_id}\n" \
                                     "📅 Дата: #{booking_data[:date]}\n" \
                                     "⏰ Время: #{booking_data[:time]}\n" \
                                     "🏢 Центр: #{ServicePoint.find(booking_data[:service_point_id]).name}\n" \
                                     "📱 Телефон: #{booking_data[:phone]}\n\n" \
                                     "Мы свяжемся с вами для подтверждения.")
      else
        error_response = JSON.parse(response.body) rescue {}
        error_message = error_response['error'] || 'Неизвестная ошибка'
        
        Rails.logger.error "Guest booking creation failed: #{error_message}"
        send_message(session.chat_id, "❌ Ошибка создания гостевого бронирования: #{error_message}")
      end
      
    rescue => e
      Rails.logger.error "Error creating guest booking: #{e.message}\n#{e.backtrace.join("\n")}"
      send_message(session.chat_id, "❌ Произошла ошибка при создании гостевого бронирования. Попробуйте позже.")
    end
  end

  def handle_settings_callback(chat_id, callback_data, message_id)
    # Существующая логика настроек
    case callback_data
    when 'settings'
      handle_settings_command(chat_id)
    when 'start_booking'
      handle_booking_command(chat_id)
    # ... остальные callback'и
    end
  end

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
      address = point.address.present? ? " (#{point.address})" : ""
      [{ text: "#{point.name}#{address}", callback_data: "booking_point_#{point.id}" }]
    end
    
    { inline_keyboard: buttons }
  end

  def build_calendar_keyboard
    # Простая реализация календаря на 14 дней вперед
    buttons = []
    current_date = Date.current
    
    (0..13).each do |day_offset|
      date = current_date + day_offset.days
      next if date.sunday? # Пропускаем воскресенья
      
      day_name = I18n.l(date, format: '%A, %d.%m', locale: :ru)
      buttons << [{ text: day_name, callback_data: "booking_date_#{date.strftime('%Y-%m-%d')}" }]
    end
    
    { inline_keyboard: buttons }
  end

  def build_car_types_keyboard(car_types)
    buttons = car_types.map do |car_type|
      [{ text: car_type.name, callback_data: "booking_car_type_#{car_type.id}" }]
    end
    
    { inline_keyboard: buttons }
  end

  private

  def handle_response(response)
    if response.success?
      JSON.parse(response.body, symbolize_names: true)
    else
      {
        ok: false,
        error_code: response.code,
        description: response.message
      }
    end
  rescue JSON::ParserError => e
    {
      ok: false,
      error_code: 'parse_error',
      description: "Помилка парсингу відповіді: #{e.message}"
    }
  end

  def handle_start_command(chat_id, user_data)
    message = "🚗 Вітаємо в Tire Service!\n\n" \
              "Я надсилатиму вам сповіщення про:\n" \
              "• Статус ваших бронювань\n" \
              "• Нагадування про майбутні візити\n" \
              "• Спеціальні пропозиції\n\n" \
              "Також ви можете створити бронювання прямо тут!\n\n" \
              "Для налаштування сповіщень використовуйте /settings\n" \
              "Для відключення сповіщень використовуйте /stop"
    
    keyboard = {
      inline_keyboard: [
        [{ text: "📅 Створити бронювання", callback_data: 'start_booking' }],
        [{ text: "🌐 Відкрити сайт", url: ENV['FRONTEND_URL'] || 'http://localhost:3008' }],
        [{ text: "⚙️ Налаштування", callback_data: 'settings' }]
      ]
    }
    
    send_message(chat_id, message, keyboard)
  end

  def handle_stop_command(chat_id)
    # Деактивируем подписку
    subscription = TelegramSubscription.find_by(chat_id: chat_id)
    if subscription
      subscription.deactivate!
      message = "🔕 Сповіщення відключено.\n\nДля повторного включення використовуйте /start"
    else
      message = "❓ Підписка не знайдена."
    end
    
    send_message(chat_id, message)
  end

  def handle_help_command(chat_id)
    message = "📋 Доступні команди:\n\n" \
              "/start - Включити сповіщення\n" \
              "/booking - Створити бронювання 📅\n" \
              "/stop - Відключити сповіщення\n" \
              "/status - Статус підписки\n" \
              "/settings - Налаштування сповіщень\n" \
              "/help - Ця довідка\n\n" \
              "🌐 Сайт: #{ENV['FRONTEND_URL'] || 'http://localhost:3008'}"
    
    send_message(chat_id, message)
  end

  def handle_status_command(chat_id)
    subscription = TelegramSubscription.find_by(chat_id: chat_id)
    
    if subscription
      user = subscription.user
      message = "📊 Статус підписки:\n\n" \
                "👤 Користувач: #{user.full_name}\n" \
                "📧 Email: #{user.email}\n" \
                "🔔 Статус: #{subscription.is_active? ? '✅ Активна' : '❌ Неактивна'}\n" \
                "🌍 Мова: Українська\n" \
                "📱 Сповіщень надіслано: #{subscription.sent_notifications_count}\n" \
                "📈 Успішність доставки: #{subscription.success_rate}%"
    else
      message = "❓ Підписка не знайдена. Використовуйте /start для підключення."
    end
    
    send_message(chat_id, message)
  end

  def handle_settings_command(chat_id)
    subscription = TelegramSubscription.find_by(chat_id: chat_id)
    
    if subscription
      keyboard = {
        inline_keyboard: [
          [{ text: "🔔 Бронирования", callback_data: 'toggle_booking' }],
          [{ text: "🎉 Акции", callback_data: 'toggle_promotion' }],
          [{ text: "⏰ Напоминания", callback_data: 'toggle_reminder' }],
          [{ text: "🌍 Язык", callback_data: 'change_language' }]
        ]
      }
      
      message = "⚙️ Настройки уведомлений:\n\nВыберите тип уведомлений для настройки:"
      send_message(chat_id, message, keyboard)
    else
      message = "❓ Подписка не найдена. Используйте /start для подключения."
      send_message(chat_id, message)
    end
  end

  # Метод для получения категорий услуг по городу
  def get_service_categories_by_city(city_id)
    # Используем ту же логику что в ServiceCategoriesController#by_city_id
    ServiceCategory.joins(:service_posts)
                   .joins("INNER JOIN service_points ON service_points.id = service_posts.service_point_id")
                   .where("service_points.city_id = ? AND service_points.is_active = true", city_id)
                   .where("service_posts.is_active = true")
                   .distinct
                   .order(:name)
  end

  # Метод для получения сервисных точек по категории услуг
  def get_service_points_by_category(service_category_id, city_id)
    # Используем ту же логику что в ServicePointsController#by_category
    service_point_ids = ServicePost.where(service_category_id: service_category_id, is_active: true)
                                   .joins(:service_point)
                                   .where(service_points: { is_active: true, work_status: 'working', city_id: city_id })
                                   .pluck(:service_point_id)
                                   .uniq
    
    ServicePoint.where(id: service_point_ids)
                .includes(:city, :partner)
                .order(:name)
  end
end 