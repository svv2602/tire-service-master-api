# frozen_string_literal: true

# Service for sending SMS notifications
class SmsService
  class << self
    # === Authentication SMS ===

    def send_password_reset(phone, token)
      message = "Ваш код восстановления пароля в Tire Service: #{token}. Действителен 2 часа. Никому не сообщайте этот код."
      send_sms(phone, message)
    end

    # === Booking SMS ===

    def send_booking_confirmation(phone, booking)
      message = build_booking_confirmation_message(booking)
      send_sms(phone, message)
    end

    def send_booking_reminder(phone, booking)
      message = build_booking_reminder_message(booking)
      send_sms(phone, message)
    end

    def send_booking_cancelled(phone, booking)
      message = build_booking_cancelled_message(booking)
      send_sms(phone, message)
    end

    # === Order SMS ===

    def send_order_ready(phone, order)
      message = build_order_ready_message(order)
      send_sms(phone, message)
    end

    def send_order_delivered(phone, order)
      message = build_order_delivered_message(order)
      send_sms(phone, message)
    end

    # === Generic send method ===

    def send_sms(phone, message)
      return { success: false, error: 'Телефон не указан' } unless phone.present?

      case Rails.env
      when 'development', 'test'
        log_sms(phone, message)
        { success: true, message: 'SMS отправлена (режим разработки)' }
      when 'production'
        send_via_provider(phone, message)
      else
        { success: false, error: 'Неизвестная среда выполнения' }
      end
    end

    # Check if SMS service is configured
    def configured?
      twilio_configured? || turbosms_configured?
    end

    private

    # === Message builders ===

    def build_booking_confirmation_message(booking)
      service_point_name = booking.service_point&.name || 'СТО'
      date = booking.booking_date.strftime('%d.%m.%Y')
      time = booking.start_time.strftime('%H:%M')

      "Ваш запис підтверджено!\n#{service_point_name}\n#{date} о #{time}\nТел: #{booking.service_point&.phone || ''}"
    end

    def build_booking_reminder_message(booking)
      service_point_name = booking.service_point&.name || 'СТО'
      time = booking.start_time.strftime('%H:%M')
      address = booking.service_point&.address || ''

      "Нагадуємо: завтра о #{time} ви записані на #{service_point_name}.\nАдреса: #{address}"
    end

    def build_booking_cancelled_message(booking)
      service_point_name = booking.service_point&.name || 'СТО'
      date = booking.booking_date.strftime('%d.%m.%Y')
      time = booking.start_time.strftime('%H:%M')

      "Ваш запис на #{date} о #{time} в #{service_point_name} скасовано."
    end

    def build_order_ready_message(order)
      order_number = order.respond_to?(:ttn) ? order.ttn : order.order_number
      service_point_name = order.service_point&.name || 'пункт видачі'

      "Ваше замовлення #{order_number} готове до видачі в #{service_point_name}!"
    end

    def build_order_delivered_message(order)
      order_number = order.respond_to?(:ttn) ? order.ttn : order.order_number

      "Замовлення #{order_number} видано. Дякуємо за покупку!"
    end

    # === Provider methods ===

    def send_via_provider(phone, message)
      if twilio_configured?
        send_via_twilio(phone, message)
      elsif turbosms_configured?
        send_via_turbosms(phone, message)
      else
        Rails.logger.warn 'No SMS provider configured'
        { success: false, error: 'SMS провайдер не налаштований' }
      end
    end

    def send_via_twilio(phone, message)
      begin
        require 'twilio-ruby'

        client = Twilio::REST::Client.new(
          ENV['TWILIO_ACCOUNT_SID'],
          ENV['TWILIO_AUTH_TOKEN']
        )

        client.messages.create(
          from: ENV['TWILIO_PHONE_NUMBER'],
          to: normalize_phone(phone),
          body: message
        )

        Rails.logger.info "SMS sent via Twilio to #{mask_phone(phone)}"
        { success: true, message: 'SMS успішно відправлена' }
      rescue => e
        Rails.logger.error "Twilio error: #{e.message}"
        { success: false, error: "Помилка відправки SMS: #{e.message}" }
      end
    end

    def send_via_turbosms(phone, message)
      begin
        # TurboSMS HTTP API (popular Ukrainian SMS provider)
        uri = URI('https://api.turbosms.ua/message/send.json')
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        request.body = {
          recipients: [normalize_phone_ua(phone)],
          sms: {
            sender: ENV['TURBOSMS_SENDER'] || 'TireService',
            text: message
          }
        }.to_json

        request['Authorization'] = "Bearer #{ENV['TURBOSMS_API_KEY']}"

        response = http.request(request)
        result = JSON.parse(response.body)

        if result['response_code'] == 0
          Rails.logger.info "SMS sent via TurboSMS to #{mask_phone(phone)}"
          { success: true, message: 'SMS успішно відправлена' }
        else
          Rails.logger.error "TurboSMS error: #{result['response_status']}"
          { success: false, error: result['response_status'] }
        end
      rescue => e
        Rails.logger.error "TurboSMS error: #{e.message}"
        { success: false, error: "Помилка відправки SMS: #{e.message}" }
      end
    end

    # === Configuration checks ===

    def twilio_configured?
      ENV['TWILIO_ACCOUNT_SID'].present? &&
        ENV['TWILIO_AUTH_TOKEN'].present? &&
        ENV['TWILIO_PHONE_NUMBER'].present?
    end

    def turbosms_configured?
      ENV['TURBOSMS_API_KEY'].present?
    end

    # === Phone normalization ===

    def normalize_phone(phone)
      normalized = phone.to_s.gsub(/[^\d+]/, '')

      if normalized.start_with?('8')
        normalized = '+7' + normalized[1..-1]
      elsif normalized.start_with?('7') && !normalized.start_with?('+7')
        normalized = '+' + normalized
      elsif !normalized.start_with?('+')
        normalized = '+' + normalized
      end

      normalized
    end

    def normalize_phone_ua(phone)
      normalized = phone.to_s.gsub(/[^\d]/, '')

      # Ukrainian phone format
      if normalized.start_with?('380')
        normalized
      elsif normalized.start_with?('80')
        '3' + normalized
      elsif normalized.start_with?('0')
        '38' + normalized
      else
        '380' + normalized
      end
    end

    def mask_phone(phone)
      return '' unless phone.present?

      phone_str = phone.to_s
      if phone_str.length > 6
        phone_str[0..3] + '***' + phone_str[-3..-1]
      else
        '***'
      end
    end

    def log_sms(phone, message)
      Rails.logger.info "=" * 50
      Rails.logger.info "[SMS DEV MODE] To: #{phone}"
      Rails.logger.info "[SMS DEV MODE] Message: #{message}"
      Rails.logger.info "=" * 50
    end
  end
end 