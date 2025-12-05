# frozen_string_literal: true

require 'httparty'
require 'securerandom'

module Telegram
  # BookingFlow - процесс бронирования через Telegram
  # Отвечает за: шаги бронирования, создание бронирований
  class BookingFlow
    attr_reader :api_client, :formatter

    def initialize(api_client:, formatter: nil)
      @api_client = api_client
      @formatter = formatter || MessageFormatter.new
    end

    # === Управление сессией ===

    def start_booking(chat_id)
      # Очищаем существующую сессию
      TelegramBookingSession.active.find_by(chat_id: chat_id)&.destroy

      session = TelegramBookingSession.create!(
        chat_id: chat_id,
        current_step: TelegramBookingSession::BOOKING_STEPS[:city_selection],
        expires_at: 1.hour.from_now
      )

      start_city_selection(chat_id, session)
    end

    def handle_step(chat_id, text, session)
      case session.current_step
      when 'phone_input'
        handle_phone_input(chat_id, text, session)
      when 'license_plate_input'
        handle_license_plate_input(chat_id, text, session)
      when 'comment_input'
        handle_comment_input(chat_id, text, session)
      else
        api_client.send_message(chat_id, '❓ Пожалуйста, используйте кнопки для выбора.')
      end
    end

    def handle_callback(chat_id, callback_data, message_id, session)
      case callback_data
      when /^booking_city_(\d+)$/
        handle_city_selection(chat_id, ::Regexp.last_match(1).to_i, session)
      when /^booking_service_(\d+)$/
        handle_service_selection(chat_id, ::Regexp.last_match(1).to_i, session)
      when /^booking_point_(\d+)$/
        handle_point_selection(chat_id, ::Regexp.last_match(1).to_i, session)
      when /^booking_date_(.+)$/
        handle_date_selection(chat_id, ::Regexp.last_match(1), session)
      when /^booking_time_(.+)$/
        handle_time_selection(chat_id, ::Regexp.last_match(1), session)
      when /^booking_car_type_(\d+)$/
        handle_car_type_selection(chat_id, ::Regexp.last_match(1).to_i, session)
      when 'booking_skip_comment'
        handle_skip_comment(chat_id, session)
      when 'booking_confirm'
        create_booking(chat_id, session)
      when 'booking_cancel'
        cancel_booking(chat_id, session)
      end
    end

    private

    # === Шаги бронирования ===

    def start_city_selection(chat_id, _session)
      message = "🏙️ <b>Шаг 1/8: Выберите город</b>\n\n" \
                'Выберите город, где хотите записаться на обслуживание:'

      cities = City.joins(:service_points)
                   .where(service_points: { work_status: 'working', is_active: true })
                   .distinct
                   .order(:name)

      keyboard = formatter.build_cities_keyboard(cities)
      api_client.send_message(chat_id, message, keyboard: keyboard)
    end

    def handle_city_selection(chat_id, city_id, session)
      session.update_step('service_selection', { city_id: city_id })
      start_service_selection(chat_id, session)
    end

    def start_service_selection(chat_id, session)
      city_id = session.get_data(:city_id)
      city = City.find(city_id)

      message = "🔧 <b>Шаг 2/8: Выберите тип услуги</b>\n\n" \
                "Доступные услуги в городе <b>#{city.name}</b>:"

      categories = get_service_categories_by_city(city_id)

      if categories.empty?
        api_client.send_message(chat_id, "❌ В городе #{city.name} пока нет доступных услуг.")
        return
      end

      keyboard = formatter.build_service_categories_keyboard(categories)
      api_client.send_message(chat_id, message, keyboard: keyboard)
    end

    def handle_service_selection(chat_id, service_category_id, session)
      session.update_step('service_point_selection', { service_category_id: service_category_id })
      start_service_point_selection(chat_id, session)
    end

    def start_service_point_selection(chat_id, session)
      city_id = session.get_data(:city_id)
      service_category_id = session.get_data(:service_category_id)
      city = City.find(city_id)
      service_category = ServiceCategory.find(service_category_id)

      message = "📍 <b>Шаг 3/8: Выберите сервисный центр</b>\n\n" \
                "Доступные центры в городе <b>#{city.name}</b>\n" \
                "для услуги <b>#{service_category.name}</b>:"

      service_points = get_service_points_by_category(service_category_id, city_id)

      if service_points.empty?
        api_client.send_message(chat_id, "❌ В городе #{city.name} нет доступных центров для услуги \"#{service_category.name}\".")
        return
      end

      keyboard = formatter.build_service_points_keyboard(service_points)
      api_client.send_message(chat_id, message, keyboard: keyboard)
    end

    def handle_point_selection(chat_id, service_point_id, session)
      session.update_step('datetime_selection', { service_point_id: service_point_id })
      start_datetime_selection(chat_id, session)
    end

    def start_datetime_selection(chat_id, _session)
      message = "📅 <b>Шаг 4/8: Выберите дату</b>\n\n" \
                'Выберите удобную дату для записи:'

      keyboard = formatter.build_calendar_keyboard
      api_client.send_message(chat_id, message, keyboard: keyboard)
    end

    def handle_date_selection(chat_id, date, session)
      session.update_step('datetime_selection', { date: date })
      start_time_selection(chat_id, session, date)
    end

    def start_time_selection(chat_id, session, date)
      service_point_id = session.get_data(:service_point_id)
      service_category_id = session.get_data(:service_category_id)

      message = "⏰ <b>Выберите время</b>\n\n" \
                "Доступное время на #{Date.parse(date).strftime('%d.%m.%Y')}:"

      time_slots = fetch_available_time_slots(service_point_id, date, service_category_id)

      if time_slots.empty?
        api_client.send_message(chat_id, '❌ На выбранную дату нет доступного времени. Попробуйте выбрать другую дату.')
        return
      end

      keyboard = formatter.build_time_slots_keyboard(time_slots)
      api_client.send_message(chat_id, message, keyboard: keyboard)
    end

    def handle_time_selection(chat_id, time, session)
      current_date = session.get_data(:date)
      session.update_step('car_type_selection', { time: time, date: current_date })
      start_car_type_selection(chat_id, session)
    end

    def start_car_type_selection(chat_id, _session)
      message = "🚗 <b>Шаг 5/8: Выберите тип автомобиля</b>\n\n" \
                'Укажите тип вашего автомобиля:'

      car_types = CarType.active.order(:name)
      keyboard = formatter.build_car_types_keyboard(car_types)
      api_client.send_message(chat_id, message, keyboard: keyboard)
    end

    def handle_car_type_selection(chat_id, car_type_id, session)
      session.update_step('phone_input', { car_type_id: car_type_id })
      start_phone_input(chat_id, session)
    end

    def start_phone_input(chat_id, _session)
      message = "📱 <b>Шаг 6/8: Укажите номер телефона</b>\n\n" \
                "Введите ваш номер телефона в формате +380XXXXXXXXX\n" \
                'Например: +380671234567'

      keyboard = formatter.build_phone_request_keyboard
      api_client.send_message(chat_id, message, keyboard: keyboard)
    end

    def handle_phone_input(chat_id, text, session)
      phone = text.gsub(/[^\d+]/, '')

      if phone.match?(/^\+380\d{9}$/)
        session.update_step('license_plate_input', { phone: phone })
        start_license_plate_input(chat_id, session)
      else
        api_client.send_message(chat_id, '❌ Неверный формат номера. Пожалуйста, введите номер в формате +380XXXXXXXXX')
      end
    end

    def start_license_plate_input(chat_id, _session)
      message = "🚙 <b>Шаг 7/8: Укажите номер автомобиля</b>\n\n" \
                "Введите государственный номер вашего автомобиля.\n" \
                'Например: AA1234BB'

      keyboard = formatter.remove_keyboard
      api_client.send_message(chat_id, message, keyboard: keyboard)
    end

    def handle_license_plate_input(chat_id, text, session)
      license_plate = text.strip

      if license_plate.present? && license_plate.length >= 1
        session.update_step('comment_input', { license_plate: license_plate })
        start_comment_input(chat_id, session)
      else
        api_client.send_message(chat_id, '❌ Пожалуйста, введите номер автомобиля.')
      end
    end

    def start_comment_input(chat_id, _session)
      message = "💬 <b>Шаг 8/8: Комментарий (опционально)</b>\n\n" \
                "Есть ли у вас дополнительные пожелания или комментарии?\n\n" \
                'Вы можете пропустить этот шаг, нажав кнопку "Пропустить".'

      keyboard = formatter.build_skip_keyboard
      api_client.send_message(chat_id, message, keyboard: keyboard)
    end

    def handle_comment_input(chat_id, text, session)
      session.update_step('confirmation', { comment: text.strip })
      show_confirmation(chat_id, session)
    end

    def handle_skip_comment(chat_id, session)
      session.update_step('confirmation', { comment: '' })
      show_confirmation(chat_id, session)
    end

    def show_confirmation(chat_id, session)
      booking_data = session.booking_data

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

      message += "💬 Комментарий: #{booking_data[:comment]}\n" if booking_data[:comment].present?
      message += "\n<b>Все данные верны?</b>"

      keyboard = formatter.build_confirmation_keyboard
      api_client.send_message(chat_id, message, keyboard: keyboard)
    end

    def create_booking(chat_id, session)
      booking_data = session.booking_data

      phone = booking_data[:phone]
      user = User.find_by(phone: phone)

      if user&.client
        create_regular_booking(user.client, booking_data, session)
      else
        create_guest_booking(booking_data, session)
      end

      session.destroy
    rescue StandardError => e
      Rails.logger.error "Ошибка создания бронирования: #{e.message}"
      api_client.send_message(chat_id, '❌ Произошла ошибка при создании бронирования. Попробуйте позже.')
    end

    def cancel_booking(chat_id, session)
      session.destroy
      api_client.send_message(chat_id, '❌ Бронирование отменено.')
    end

    # === Вспомогательные методы ===

    def get_service_categories_by_city(city_id)
      ServiceCategory.joins(:service_posts)
                     .joins('INNER JOIN service_points ON service_points.id = service_posts.service_point_id')
                     .where('service_points.city_id = ? AND service_points.is_active = true', city_id)
                     .where('service_posts.is_active = true')
                     .distinct
                     .order(:name)
    end

    def get_service_points_by_category(service_category_id, city_id)
      service_point_ids = ServicePost.where(service_category_id: service_category_id, is_active: true)
                                     .joins(:service_point)
                                     .where(service_points: { is_active: true, work_status: 'working', city_id: city_id })
                                     .pluck(:service_point_id)
                                     .uniq

      ServicePoint.where(id: service_point_ids)
                  .includes(:city, :partner)
                  .order(:name)
    end

    def fetch_available_time_slots(service_point_id, date, category_id)
      response = HTTParty.get(
        'http://localhost:8000/api/v1/availability/slots_for_category',
        query: { service_point_id: service_point_id, date: date, category_id: category_id },
        headers: { 'Content-Type' => 'application/json' }
      )

      return [] unless response.success? && response.parsed_response['slots']

      response.parsed_response['slots']
              .select { |slot| (slot['available_posts'] || 0).positive? }
              .map { |slot| slot['start_time'] }
              .uniq
              .sort
    rescue StandardError => e
      Rails.logger.error "Error fetching time slots: #{e.message}"
      []
    end

    def create_regular_booking(client, booking_data, session)
      payload = build_booking_payload(booking_data, client)

      response = HTTParty.post(
        'http://localhost:8000/api/v1/client_bookings',
        headers: { 'Content-Type' => 'application/json' },
        body: payload.to_json
      )

      handle_booking_response(response, booking_data, session)
    end

    def create_guest_booking(booking_data, session)
      payload = build_guest_booking_payload(booking_data)

      response = HTTParty.post(
        'http://localhost:8000/api/v1/client_bookings',
        headers: { 'Content-Type' => 'application/json' },
        body: payload.to_json
      )

      handle_booking_response(response, booking_data, session, guest: true)
    end

    def build_booking_payload(booking_data, client)
      {
        booking: {
          service_point_id: booking_data[:service_point_id],
          service_category_id: booking_data[:service_category_id],
          car_type_id: booking_data[:car_type_id],
          booking_date: booking_data[:date],
          start_time: booking_data[:time],
          license_plate: booking_data[:license_plate],
          car_brand: 'Не указана',
          car_model: 'Не указана',
          notes: booking_data[:comment] || '',
          service_recipient_first_name: client.user.first_name,
          service_recipient_last_name: client.user.last_name,
          service_recipient_phone: client.user.phone,
          service_recipient_email: client.user.email
        },
        client_id: client.id
      }
    end

    def build_guest_booking_payload(booking_data)
      {
        booking: {
          service_point_id: booking_data[:service_point_id],
          service_category_id: booking_data[:service_category_id],
          car_type_id: booking_data[:car_type_id],
          booking_date: booking_data[:date],
          start_time: booking_data[:time],
          license_plate: booking_data[:license_plate],
          car_brand: 'Не указана',
          car_model: 'Не указана',
          notes: booking_data[:comment] || '',
          service_recipient_first_name: booking_data[:first_name] || 'Гость',
          service_recipient_last_name: booking_data[:last_name] || 'Telegram',
          service_recipient_phone: booking_data[:phone],
          service_recipient_email: "guest_telegram_#{SecureRandom.hex(4)}@tire-service.local"
        }
      }
    end

    def handle_booking_response(response, booking_data, session, guest: false)
      if response.success?
        booking_response = JSON.parse(response.body)
        booking_id = booking_response['id']
        service_point = ServicePoint.find(booking_data[:service_point_id])
        type_label = guest ? 'Гостевое бронирование' : 'Бронирование'

        message = "✅ <b>#{type_label} успешно создано!</b>\n\n" \
                  "📋 ID бронирования: #{booking_id}\n" \
                  "📅 Дата: #{booking_data[:date]}\n" \
                  "⏰ Время: #{booking_data[:time]}\n" \
                  "🏢 Центр: #{service_point.name}\n"
        message += "📱 Телефон: #{booking_data[:phone]}\n" if guest
        message += guest ? "\nМы свяжемся с вами для подтверждения." : "\nВы получите уведомление о подтверждении."

        api_client.send_message(session.chat_id, message)
      else
        error_response = JSON.parse(response.body) rescue {}
        error_message = error_response['error'] || 'Неизвестная ошибка'
        Rails.logger.error "Booking creation failed: #{error_message}"
        api_client.send_message(session.chat_id, "❌ Ошибка создания бронирования: #{error_message}")
      end
    end
  end
end
