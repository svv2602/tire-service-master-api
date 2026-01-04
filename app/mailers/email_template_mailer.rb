# Универсальный mailer для отправки email с использованием шаблонов из базы данных
class EmailTemplateMailer < ApplicationMailer
  default from: ENV.fetch('SMTP_FROM_EMAIL', 'noreply@tireservice.ua'),
          charset: 'UTF-8',
          content_type: 'text/html'

  # Основной метод для отправки email по шаблону
  def send_by_template(template_type, recipient_email, variables = {}, language = 'uk')
    # Находим активный шаблон для указанного языка, если не найден - пробуем украинский
    template = EmailTemplate.active.find_by(template_type: template_type, language: language)
    template ||= EmailTemplate.active.find_by(template_type: template_type, language: 'uk')
    
    unless template
      Rails.logger.error "📧 Шаблон не найден: #{template_type}"
      return nil
    end

    # Рендерим шаблон с переменными
    rendered = template.render_with_all_variables(variables)
    subject = rendered[:subject]
    html_body = rendered[:body]

    # Принудительно устанавливаем UTF-8 кодировку для темы
    subject_utf8 = subject.force_encoding('UTF-8')

    # Создаем запись в логе уведомлений
    notification_log = NotificationLog.create!(
      notification_type: 'email',
      template_type: template_type,
      template_id: template.id,
      recipient_type: 'User', # Можно сделать более гибким
      recipient_email: recipient_email,
      status: 'pending',
      metadata: {
        variables: variables,
        template_name: template.name,
        subject: subject_utf8
      }
    )

    begin
      # Отправляем письмо
      mail = mail(
        to: recipient_email,
        subject: subject_utf8,
        body: html_body,
        content_type: 'text/html; charset=UTF-8'
      ) do |format|
        format.html { render plain: html_body }
      end
      
      # Отмечаем как отправленное
      notification_log.mark_as_sent!
      notification_log.add_metadata('mail_message_id', mail.message_id) if mail.message_id
      
      Rails.logger.info "📧 Email отправлен: #{template_type} на #{recipient_email} (Log ID: #{notification_log.id})"
      
      mail
    rescue => e
      # Отмечаем как неудачное
      notification_log.mark_as_failed!(e.message)
      
      Rails.logger.error "📧 Ошибка отправки email: #{e.message} (Log ID: #{notification_log.id})"
      raise e
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
  def password_reset(user_id, reset_token, language = 'ru')
    user = User.find_by(id: user_id)
    return nil unless user&.email.present?

    variables = build_user_variables(user)
    variables.merge!({
      'reset_token' => reset_token,
      'reset_url' => "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3008')}/reset-password?token=#{reset_token}"
    })
    
    send_by_template('password_reset', user.email, variables, language)
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

  # Построение переменных для бронирования
  def build_booking_variables(booking)
    {
      booking_id: "##{booking.id}",
      booking_number: booking.id.to_s,
      booking_date: booking.booking_date&.strftime('%d.%m.%Y'),
      start_time: booking.start_time&.strftime('%H:%M'),
      end_time: booking.end_time&.strftime('%H:%M'),
      service_point_name: booking.service_point&.name,
      service_point_address: booking.service_point&.address,
      service_point_phone: booking.service_point&.contact_phone,
      city_name: booking.service_point&.city&.name,
      client_first_name: booking.service_recipient_first_name || booking.client&.first_name,
      client_last_name: booking.service_recipient_last_name || booking.client&.last_name,
      client_phone: booking.service_recipient_phone || booking.client&.phone,
      client_email: booking.service_recipient_email || booking.client&.email,
      car_brand: booking.car_brand,
      car_model: booking.car_model,
      license_plate: booking.license_plate,
      status: booking.status
    }
  end
  
  # Построение переменных для отзыва
  def build_review_variables(review)
    {
      review_id: "##{review.id}",
      review_number: review.id.to_s,
      rating: review.rating.to_s,
      rating_stars: "⭐" * review.rating,
      comment: review.comment || 'Без коментаря',
      status: review.status,
      status_text: case review.status
                   when 'pending' then 'На розгляді'
                   when 'published' then 'Опубліковано'
                   when 'rejected' then 'Відхилено'
                   else review.status
                   end,
      client_first_name: review.client&.first_name,
      client_last_name: review.client&.last_name,
      client_phone: review.client&.phone,
      client_email: review.client&.email,
      service_point_name: review.service_point&.name,
      service_point_address: review.service_point&.address,
      service_point_phone: review.service_point&.phone,
      city_name: review.service_point&.city&.name,
      created_date: review.created_at&.strftime('%d.%m.%Y'),
      created_time: review.created_at&.strftime('%H:%M'),
      # Данные бронирования если есть
      booking_id: review.booking ? "##{review.booking.id}" : 'Без бронювання',
      car_brand: review.booking&.car_brand,
      car_model: review.booking&.car_model,
      license_plate: review.booking&.license_plate
    }
  end
  
  # Строит переменные для сервисной точки
  def build_service_point_variables(service_point)
    {
      service_point_id: "##{service_point.id}",
      service_point_name: service_point.name,
      service_point_address: service_point.address,
      service_point_phone: service_point.phone,
      service_point_email: service_point.email,
      service_point_status: service_point.status,
      service_point_status_text: case service_point.status
                                  when 'active' then 'Активна'
                                  when 'inactive' then 'Неактивна'
                                  else service_point.status
                                  end,
      service_point_city: service_point.city&.name,
      service_point_created_date: service_point.created_at&.strftime('%d.%m.%Y'),
      service_point_created_time: service_point.created_at&.strftime('%H:%M')
    }
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
  
  # Админские уведомления об отзывах
  def admin_new_review(review_id, admin_email)
    review = Review.find_by(id: review_id)
    return nil unless review
    return nil unless admin_email.present?
    variables = build_review_variables(review)
    send_by_template('admin_new_review', admin_email, variables)
  end
  
  # Уведомления клиентам об отзывах
  def review_published(review_id, client_email)
    review = Review.find_by(id: review_id)
    return nil unless review
    return nil unless client_email.present?
    variables = build_review_variables(review)
    send_by_template('review_published', client_email, variables)
  end
  
  def review_rejected(review_id, client_email)
    review = Review.find_by(id: review_id)
    return nil unless review
    return nil unless client_email.present?
    variables = build_review_variables(review)
    send_by_template('review_rejected', client_email, variables)
  end
  
  # Админские уведомления о сервисных точках
  def admin_service_point_created(service_point_id, admin_email)
    service_point = ServicePoint.find_by(id: service_point_id)
    return nil unless service_point
    return nil unless admin_email.present?
    variables = build_service_point_variables(service_point)
    send_by_template('admin_service_point_created', admin_email, variables)
  end
  
  def admin_service_point_changed(service_point_id, admin_email)
    service_point = ServicePoint.find_by(id: service_point_id)
    return nil unless service_point
    return nil unless admin_email.present?
    variables = build_service_point_variables(service_point)
    send_by_template('admin_service_point_changed', admin_email, variables)
  end
  
  def admin_service_point_status_changed(service_point_id, admin_email)
    service_point = ServicePoint.find_by(id: service_point_id)
    return nil unless service_point
    return nil unless admin_email.present?
    variables = build_service_point_variables(service_point)
    send_by_template('admin_service_point_status_changed', admin_email, variables)
  end

  # === ПАРТНЁРСКИЕ УВЕДОМЛЕНИЯ ===

  # Уведомление партнёра о новой записи
  def partner_new_booking(booking_id, partner_email)
    booking = Booking.find_by(id: booking_id)
    return nil unless booking
    return nil unless partner_email.present?

    variables = build_partner_booking_variables(booking)
    send_by_template('partner_new_booking', partner_email, variables)
  end

  # Уведомление партнёра об отмене записи
  def partner_booking_cancelled(booking_id, partner_email)
    booking = Booking.find_by(id: booking_id)
    return nil unless booking
    return nil unless partner_email.present?

    variables = build_partner_booking_variables(booking)
    send_by_template('partner_booking_cancelled', partner_email, variables)
  end

  # Построение переменных для партнёрского уведомления о бронировании
  def build_partner_booking_variables(booking)
    build_booking_variables(booking).merge({
      partner_name: booking.service_point&.partner&.user&.full_name || 'Партнер',
      partner_email: booking.service_point&.partner&.user&.email,
      partner_phone: booking.service_point&.partner&.user&.phone,
      service_category_name: booking.service_category&.name || 'Не указана',
      action_url: "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3008')}/admin/bookings/#{booking.id}/edit",
      confirm_url: "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3008')}/admin/bookings?action=confirm&id=#{booking.id}",
      total_price: booking.total_price&.to_s || '0',
      notes: booking.notes || 'Без дополнительных комментариев'
    })
  end

  private

  # Строит системные переменные
  def build_system_variables
    {
      'company_name' => 'Tire Service Master',
      'support_email' => ENV.fetch('SUPPORT_EMAIL', 'support@tireservice.ua'),
      'support_phone' => ENV.fetch('SUPPORT_PHONE', '+38 (044) 111-22-33'),
      'website_url' => ENV.fetch('FRONTEND_URL', 'http://localhost:3008'),
      'current_date' => Date.current.strftime('%d.%m.%Y'),
      'current_time' => Time.current.strftime('%H:%M'),
      'emergency_contact' => 'В экстренных случаях звоните: +38 (044) 111-22-33',
      'current_promotion' => '🎯 Специальное предложение: скидка 10% на все услуги!',
      'additional_services' => 'Дополнительные услуги: диагностика, ремонт подвески, замена масла',
      'seasonal_recommendation' => 'Рекомендация: проверьте давление в шинах перед поездкой',
      'weather_warning' => 'Внимание: возможны изменения в расписании из-за погодных условий',
      'loyalty_bonus' => '💎 Бонус постоянного клиента: +50 баллов на счет',
      'newsletter_content' => 'Новости компании и полезные советы по уходу за автомобилем'
    }
  end


end 