# Универсальный mailer для отправки email с использованием шаблонов из базы данных
class EmailTemplateMailer < ApplicationMailer
  default from: ENV.fetch('SMTP_FROM_EMAIL', 'noreply@tireservice.ua'),
          charset: 'UTF-8',
          content_type: 'text/html'

  # Основной метод для отправки email по шаблону
  def send_by_template(template_type, recipient_email, variables = {})
    # Находим активный шаблон по типу
    template = EmailTemplate.find_by(template_type: template_type, is_active: true, language: 'uk')
    
    unless template
      Rails.logger.error "EmailTemplate не найден: template_type=#{template_type}, language=uk"
      return nil
    end

    # Загружаем кастомные переменные для этого шаблона
    custom_variables = {}
    template.custom_variables.active.each do |custom_var|
      custom_variables[custom_var.name] = custom_var.example_value || "[#{custom_var.name}]"
    end

    # Объединяем системные и кастомные переменные
    all_variables = variables.merge(custom_variables)
    
    # Заменяем переменные в шаблоне
    subject = replace_variables(template.subject, all_variables)
    body = replace_variables(template.body, all_variables)
    
    # Конвертируем переносы строк в HTML и добавляем HTML заголовки
    html_body = %{
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
  <title>#{subject}</title>
</head>
<body>
#{body.gsub(/\r\n|\r|\n/, '<br/>')}
</body>
</html>
    }.strip.html_safe
    
    Rails.logger.info "📧 Отправка email по шаблону: #{template.name} → #{recipient_email}"
    
    # Принудительно устанавливаем кодировку для subject
    subject_utf8 = subject.force_encoding('UTF-8')
    
    mail(
      to: recipient_email,
      subject: subject_utf8,
      body: html_body,
      content_type: 'text/html; charset=UTF-8'
    ) do |format|
      format.html { render plain: html_body }
    end
  end

  # Отправка подтверждения бронирования
  def booking_confirmation(booking_id, recipient_email = nil)
    booking = Booking.find_by(id: booking_id)
    return nil unless booking

    recipient_email ||= booking.service_recipient_email || booking.client&.email
    return nil unless recipient_email.present?

    variables = build_booking_variables(booking)
    send_by_template('booking_confirmation', recipient_email, variables)
  end

  # Отправка уведомления об отмене
  def booking_cancelled(booking_id, recipient_email = nil)
    booking = Booking.find_by(id: booking_id)
    return nil unless booking

    recipient_email ||= booking.service_recipient_email || booking.client&.email
    return nil unless recipient_email.present?

    variables = build_booking_variables(booking)
    send_by_template('booking_cancelled', recipient_email, variables)
  end

  # Отправка напоминания
  def booking_reminder(booking_id, recipient_email = nil)
    booking = Booking.find_by(id: booking_id)
    return nil unless booking

    recipient_email ||= booking.service_recipient_email || booking.client&.email
    return nil unless recipient_email.present?

    variables = build_booking_variables(booking)
    send_by_template('booking_reminder', recipient_email, variables)
  end

  # Отправка уведомления о завершении обслуживания
  def service_completed(booking_id, recipient_email = nil)
    booking = Booking.find_by(id: booking_id)
    return nil unless booking

    recipient_email ||= booking.service_recipient_email || booking.client&.email
    return nil unless recipient_email.present?

    variables = build_booking_variables(booking)
    send_by_template('service_completed', recipient_email, variables)
  end

  # Отправка запроса на отзыв
  def review_request(booking_id, recipient_email = nil)
    booking = Booking.find_by(id: booking_id)
    return nil unless booking

    recipient_email ||= booking.service_recipient_email || booking.client&.email
    return nil unless recipient_email.present?

    variables = build_booking_variables(booking)
    send_by_template('review_request', recipient_email, variables)
  end

  # Приветствие нового пользователя
  def user_welcome(user_id)
    user = User.find_by(id: user_id)
    return nil unless user&.email.present?

    variables = build_user_variables(user)
    send_by_template('user_welcome', user.email, variables)
  end

  # Сброс пароля
  def password_reset(user_id, reset_token)
    user = User.find_by(id: user_id)
    return nil unless user&.email.present?

    variables = build_user_variables(user)
    variables.merge!({
      'reset_token' => reset_token,
      'reset_url' => "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3008')}/auth/reset-password?token=#{reset_token}"
    })
    
    send_by_template('password_reset', user.email, variables)
  end

  # Информационная рассылка
  def newsletter(recipient_email, custom_variables = {})
    variables = build_system_variables.merge(custom_variables)
    send_by_template('newsletter', recipient_email, variables)
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

  # Строит переменные для бронирования
  def build_booking_variables(booking)
    variables = build_system_variables

    # Клиент
    variables.merge!({
      'client_name' => "#{booking.service_recipient_first_name} #{booking.service_recipient_last_name}".strip,
      'client_email' => booking.service_recipient_email || booking.client&.email || '',
      'client_phone' => booking.service_recipient_phone || booking.client&.phone || '',
      'client_first_name' => booking.service_recipient_first_name || booking.client&.first_name || '',
      'client_last_name' => booking.service_recipient_last_name || booking.client&.last_name || ''
    })

    # Бронирование
    variables.merge!({
      'booking_id' => "##{booking.id}",
      'booking_number' => booking.id.to_s,
      'booking_date' => booking.booking_date&.strftime('%d.%m.%Y') || '',
      'booking_time' => booking.start_time&.strftime('%H:%M') || '',
      'booking_status' => booking.status&.humanize || '',
      'booking_notes' => booking.notes || ''
    })

    # Сервисная точка
    if booking.service_point
      variables.merge!({
        'service_point_name' => booking.service_point.name || '',
        'service_point_address' => booking.service_point.address || '',
        'service_point_phone' => booking.service_point.contact_phone_for_category(booking.service_category_id) || '',
        'service_point_email' => booking.service_point.contact_email_for_category(booking.service_category_id) || '',
        'service_point_city' => booking.service_point.city&.name || ''
      })
    end

          # Услуги
      if booking.service_category
        variables.merge!({
          'service_name' => booking.service_category.name || '',
          'service_category' => booking.service_category.name || '',
          'service_price' => booking.total_price ? "#{booking.total_price} грн" : '',
          'service_duration' => '', # Длительность теперь настраивается в service_point_services
          'service_description' => booking.service_category.description || ''
        })
      end

    # Автомобиль
    variables.merge!({
      'car_brand' => booking.car_brand || '',
      'car_model' => booking.car_model || '',
      'car_year' => '', # У Booking нет поля car_year
      'license_plate' => booking.license_plate || ''
    })

    variables
  end

  # Строит переменные для пользователя
  def build_user_variables(user)
    variables = build_system_variables

    variables.merge!({
      'client_name' => user.full_name || "#{user.first_name} #{user.last_name}".strip,
      'client_email' => user.email || '',
      'client_phone' => user.phone || '',
      'client_first_name' => user.first_name || '',
      'client_last_name' => user.last_name || ''
    })

    variables
  end

  # Уведомление об изменении времени бронирования
  def booking_time_changed(booking_id, recipient_email = nil)
    booking = Booking.find_by(id: booking_id)
    return nil unless booking

    recipient_email ||= booking.service_recipient_email || booking.client&.email
    return nil unless recipient_email.present?

    variables = build_booking_variables(booking)
    send_by_template('booking_time_changed', recipient_email, variables)
  end

  # Уведомление об изменении сервисной точки
  def booking_location_changed(booking_id, recipient_email = nil)
    booking = Booking.find_by(id: booking_id)
    return nil unless booking

    recipient_email ||= booking.service_recipient_email || booking.client&.email
    return nil unless recipient_email.present?

    variables = build_booking_variables(booking)
    send_by_template('booking_location_changed', recipient_email, variables)
  end

  # Уведомление об изменении данных клиента
  def booking_client_info_changed(booking_id, recipient_email = nil)
    booking = Booking.find_by(id: booking_id)
    return nil unless booking

    recipient_email ||= booking.service_recipient_email || booking.client&.email
    return nil unless recipient_email.present?

    variables = build_booking_variables(booking)
    send_by_template('booking_client_info_changed', recipient_email, variables)
  end

  # === АДМИНСКИЕ УВЕДОМЛЕНИЯ ===

  # Уведомление администратора о новом бронировании
  def admin_new_booking(booking_id, admin_email)
    booking = Booking.find_by(id: booking_id)
    return nil unless booking
    return nil unless admin_email.present?

    variables = build_booking_variables(booking)
    send_by_template('admin_new_booking', admin_email, variables)
  end

  # Уведомление администратора об изменении бронирования
  def admin_booking_changed(booking_id, admin_email)
    booking = Booking.find_by(id: booking_id)
    return nil unless booking
    return nil unless admin_email.present?

    variables = build_booking_variables(booking)
    send_by_template('admin_booking_changed', admin_email, variables)
  end

  # Уведомление администратора об отмене бронирования
  def admin_booking_cancelled(booking_id, admin_email)
    booking = Booking.find_by(id: booking_id)
    return nil unless booking
    return nil unless admin_email.present?

    variables = build_booking_variables(booking)
    send_by_template('admin_booking_cancelled', admin_email, variables)
  end

  private

  # Строит системные переменные
  def build_system_variables
    {
      'company_name' => 'Tire Service Master',
      'support_email' => ENV.fetch('SUPPORT_EMAIL', 'support@tireservice.ua'),
      'support_phone' => ENV.fetch('SUPPORT_PHONE', '+38 (044) 111-22-33'),
      'website_url' => ENV.fetch('FRONTEND_URL', 'https://tireservice.ua'),
      'current_date' => Date.current.strftime('%d.%m.%Y'),
      'current_time' => Time.current.strftime('%H:%M')
    }
  end
end 