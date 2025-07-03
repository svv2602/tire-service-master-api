class SmsService
  class << self
    def send_password_reset(phone, token)
      message = "Ваш код восстановления пароля в Tire Service: #{token}. Действителен 2 часа. Никому не сообщайте этот код."
      
      case Rails.env
      when 'development', 'test'
        # В разработке просто логируем
        Rails.logger.info("SMS would be sent to #{phone}: #{message}")
        { success: true, message: 'SMS отправлена (режим разработки)' }
      when 'production'
        # В продакшене используем Twilio
        send_via_twilio(phone, message)
      else
        { success: false, error: 'Неизвестная среда выполнения' }
      end
    end

    private

    def send_via_twilio(phone, message)
      return { success: false, error: 'Twilio не настроен' } unless twilio_configured?

      begin
        client = Twilio::REST::Client.new(
          ENV['TWILIO_ACCOUNT_SID'],
          ENV['TWILIO_AUTH_TOKEN']
        )

        client.messages.create(
          from: ENV['TWILIO_PHONE_NUMBER'],
          to: normalize_phone(phone),
          body: message
        )

        { success: true, message: 'SMS успешно отправлена' }
      rescue Twilio::REST::RestError => e
        Rails.logger.error "Twilio error: #{e.message}"
        { success: false, error: "Ошибка отправки SMS: #{e.message}" }
      rescue => e
        Rails.logger.error "SMS service error: #{e.message}"
        { success: false, error: 'Внутренняя ошибка сервиса SMS' }
      end
    end

    def twilio_configured?
      ENV['TWILIO_ACCOUNT_SID'].present? &&
      ENV['TWILIO_AUTH_TOKEN'].present? &&
      ENV['TWILIO_PHONE_NUMBER'].present?
    end

    def normalize_phone(phone)
      # Приводим телефон к международному формату
      normalized = phone.gsub(/[^\d+]/, '')
      
      # Если телефон начинается с 8, заменяем на +7
      if normalized.start_with?('8')
        normalized = '+7' + normalized[1..-1]
      elsif normalized.start_with?('7') && !normalized.start_with?('+7')
        normalized = '+' + normalized
      elsif !normalized.start_with?('+')
        normalized = '+' + normalized
      end
      
      normalized
    end
  end
end 