# Контроллер для тестирования отправки email
class Api::V1::EmailTestController < ApiController
  skip_after_action :verify_authorized
  before_action :authorize_admin!

  # POST /api/v1/email_test/send_template
  # Отправка тестового email с использованием шаблона
  def send_template
    template_id = params[:template_id]
    recipient_email = params[:recipient_email]
    
    if template_id.blank? || recipient_email.blank?
      render json: { 
        error: 'Не указаны обязательные параметры',
        details: 'Требуются template_id и recipient_email'
      }, status: :bad_request
      return
    end

    template = EmailTemplate.find_by(id: template_id)
    unless template
      render json: { 
        error: 'Шаблон не найден',
        template_id: template_id
      }, status: :not_found
      return
    end

    # Полный набор тестовых данных для замены переменных
    test_variables = {
      # Клиент
      'client_name' => 'Тест Тестович',
      'client_email' => recipient_email,
      'client_phone' => '+38 (067) 123-45-67',
      'client_first_name' => 'Тест',
      'client_last_name' => 'Тестович',
      
      # Бронирование
      'booking_id' => '#TEST123',
      'booking_date' => Date.current.strftime('%d.%m.%Y'),
      'booking_time' => '14:30',
      'booking_status' => 'Підтверджено',
      'booking_notes' => 'Тестове бронювання',
      
      # Сервисная точка
      'service_point_name' => 'СТО Тестовий',
      'service_point_address' => 'вул. Тестова, 1, Київ',
      'service_point_phone' => '+38 (044) 555-12-34',
      'service_point_email' => 'test@tireservice.ua',
      'service_point_city' => 'Київ',
      
      # Услуги
      'service_name' => 'Тестова послуга',
      'service_category' => 'Тестування',
      'service_price' => '1000 грн',
      'service_duration' => '60 хвилин',
      'service_description' => 'Повний комплекс тестових послуг',
      
      # Автомобиль
      'car_brand' => 'Toyota',
      'car_model' => 'Camry',
      'car_year' => '2020',
      'license_plate' => 'ТЕ1234СТ',
      
      # Система
      'company_name' => 'Tire Service Master',
      'support_email' => 'support@tireservice.ua',
      'support_phone' => '+38 (044) 111-22-33',
      'website_url' => 'https://tireservice.ua',
      'current_date' => Date.current.strftime('%d.%m.%Y'),
      'current_time' => Time.current.strftime('%H:%M')
    }

    # Добавляем кастомные переменные из базы данных
    template.custom_variables.each do |custom_var|
      test_variables[custom_var.name] = custom_var.example_value || "[#{custom_var.name}]"
    end
    
    Rails.logger.info "📝 Загружено #{template.custom_variables.count} кастомных переменных для шаблона #{template.name}"

    begin
      # Отправляем email используя шаблон из БД
      TestMailer.send_template_email(
        template.id,
        recipient_email,
        test_variables
      ).deliver_now

      Rails.logger.info "✅ Тестовый email отправлен: #{template.name} → #{recipient_email}"

              # Получаем обработанные subject и body для ответа
        subject = replace_variables(template.subject, test_variables)
        
        render json: {
          success: true,
          message: 'Email успешно отправлен',
          template: {
            id: template.id,
            name: template.name,
            type: template.template_type,
            language: template.language
          },
          recipient: recipient_email,
          subject: subject,
          variables_used: test_variables.keys.size,
          sent_at: Time.current.iso8601
        }

    rescue => e
      Rails.logger.error "❌ Ошибка отправки email: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      render json: {
        error: 'Ошибка отправки email',
        message: e.message,
        template_id: template_id,
        recipient: recipient_email
      }, status: :internal_server_error
    end
  end

  # GET /api/v1/email_test/smtp_config
  # Проверка настроек SMTP
  def smtp_config
    smtp_settings = Rails.application.config.action_mailer.smtp_settings || {}
    
    render json: {
      smtp_configured: smtp_settings.present?,
      delivery_method: Rails.application.config.action_mailer.delivery_method,
      settings: {
        address: smtp_settings[:address] || 'не настроено',
        port: smtp_settings[:port] || 'не настроено',
        domain: smtp_settings[:domain] || 'не настроено',
        username: smtp_settings[:user_name] ? '***настроено***' : 'не настроено',
        password: smtp_settings[:password] ? '***настроено***' : 'не настроено',
        authentication: smtp_settings[:authentication] || 'не настроено'
      },
      default_url_options: Rails.application.config.action_mailer.default_url_options,
      raise_delivery_errors: Rails.application.config.action_mailer.raise_delivery_errors
    }
  end

  # POST /api/v1/email_test/simple
  # Отправка простого тестового email
  def simple
    recipient_email = params[:recipient_email]
    
    if recipient_email.blank?
      render json: { 
        error: 'Не указан recipient_email'
      }, status: :bad_request
      return
    end

    begin
      TestMailer.simple_test_email(recipient_email).deliver_now

      Rails.logger.info "✅ Простой тестовый email отправлен → #{recipient_email}"

      render json: {
        success: true,
        message: 'Простой тестовый email отправлен',
        recipient: recipient_email,
        sent_at: Time.current.iso8601
      }

    rescue => e
      Rails.logger.error "❌ Ошибка отправки простого email: #{e.message}"

      render json: {
        error: 'Ошибка отправки email',
        message: e.message,
        recipient: recipient_email
      }, status: :internal_server_error
    end
  end

  private

  # Заменяет переменные в тексте
  def replace_variables(text, variables)
    result = text.dup
    variables.each do |key, value|
      placeholder = "{#{key}}"
      result.gsub!(placeholder, value.to_s)
    end
    result
  end
end 