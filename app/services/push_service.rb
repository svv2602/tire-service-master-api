require 'webpush'
require 'json'

class PushService
  
  def initialize
    # Получаем настройки VAPID из переменных окружения
    @vapid_public_key = ENV['VAPID_PUBLIC_KEY']
    @vapid_private_key = ENV['VAPID_PRIVATE_KEY']
    @vapid_subject = ENV['VAPID_SUBJECT'] || 'mailto:admin@tireservice.ua'
    
    unless @vapid_public_key.present? && @vapid_private_key.present?
      Rails.logger.warn "⚠️ VAPID ключи не установлены в ENV, Push уведомления недоступны"
    else
      Rails.logger.info "✅ PushService инициализирован с VAPID ключами"
    end
  end

  # Отправка Push уведомления с сохранением в БД
  def send_notification(user, title, message, options = {})
    return false unless vapid_configured?
    return false unless user.push_subscriptions.any?

    success_count = 0
    total_count = user.push_subscriptions.count

    user.push_subscriptions.each do |subscription|
      begin
        # Подготавливаем payload
        payload = prepare_payload(title, message, options)
        
        # Отправляем уведомление
        response = Webpush.payload_send(
          message: payload.to_json,
          endpoint: subscription.endpoint,
          p256dh: subscription.p256dh_key,
          auth: subscription.auth_key,
          vapid: {
            subject: @vapid_subject,
            public_key: @vapid_public_key,
            private_key: @vapid_private_key
          }
        )

        if response.code == '201' || response.code == '204'
          Rails.logger.info "✅ Push уведомление отправлено пользователю #{user.id}"
          success_count += 1
          
          # Обновляем статистику подписки
          subscription.update_last_interaction!
        else
          Rails.logger.warn "⚠️ Push уведомление не доставлено: #{response.code} #{response.body}"
          
          # Если подписка недействительна, удаляем её
          if response.code == '410' || response.code == '404'
            subscription.destroy
            Rails.logger.info "🗑️ Удалена недействительная Push подписка"
          end
        end

      rescue => e
        Rails.logger.error "❌ Ошибка отправки Push уведомления: #{e.message}"
        
        # Если подписка недействительна, удаляем её
        if e.message.include?('InvalidSubscription') || e.message.include?('expired')
          subscription.destroy
          Rails.logger.info "🗑️ Удалена недействительная Push подписка: #{e.message}"
        end
      end
    end

    success_count > 0
  end

  # Форматирование уведомления о бронировании с использованием шаблонов из БД
  def format_booking_notification(booking, type, language = 'uk')
    # Пытаемся найти шаблон в БД для Push канала
    template = EmailTemplate.where(
      template_type: type,
      language: language,
      channel_type: 'push',
      is_active: true
    ).first

    if template
      # Используем шаблон из БД
      Rails.logger.info "🔔 PushService: Используем шаблон из БД: #{template.name}"
      
      # Подготавливаем переменные для шаблона
      variables = prepare_booking_variables(booking)
      
      # Рендерим шаблон с переменными
      rendered = template.render_with_variables(variables)
      
      # Для Push нужны и title и body
      title = rendered[:subject] || get_default_title_for_type(type)
      body = rendered[:body]
      
      return { title: title, body: body }
    else
      # Fallback на жестко закодированные шаблоны
      Rails.logger.warn "⚠️ PushService: Шаблон не найден в БД (#{type}, #{language}), используем fallback"
      format_booking_notification_fallback(booking, type)
    end
  end

  # Подготовка переменных для шаблонов бронирований
  def prepare_booking_variables(booking)
    # Получаем название сервиса - используем разные подходы в зависимости от доступных данных
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
    client_name = booking.client&.user&.full_name || booking.service_recipient_first_name || 'Клієнт'
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

  # Массовая отправка Push уведомлений
  def send_bulk_notification(users, title, message, options = {})
    return { total: 0, sent: 0, failed: 0, details: [] } unless vapid_configured?

    results = {
      total: users.count,
      sent: 0,
      failed: 0,
      details: []
    }

    users.each do |user|
      begin
        if send_notification(user, title, message, options)
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

    Rails.logger.info "Push масова розсилка завершена: #{results[:sent]} надіслано, #{results[:failed]} помилок"
    results
  end

  private

  def vapid_configured?
    @vapid_public_key.present? && @vapid_private_key.present?
  end

  def prepare_payload(title, message, options = {})
    payload = {
      title: title,
      body: message,
      icon: options[:icon] || '/icon-192x192.png',
      badge: options[:badge] || '/badge-72x72.png',
      tag: options[:tag] || 'tire-service',
      requireInteraction: options[:require_interaction] || false,
      timestamp: Time.current.to_i * 1000,
      data: {
        url: options[:url] || '/',
        booking_id: options[:booking_id],
        type: options[:type] || 'general'
      }
    }

    # Добавляем действия если есть
    if options[:actions]
      payload[:actions] = options[:actions]
    end

    payload
  end

  def get_default_title_for_type(type)
    case type
    when 'booking_confirmation'
      'Запис підтверджено'
    when 'booking_cancelled'
      'Запис скасовано'
    when 'booking_reminder'
      'Нагадування про запис'
    when 'service_completed'
      'Обслуговування завершено'
    when 'review_request'
      'Оцініть наш сервіс'
    else
      'Tire Service'
    end
  end

  # Fallback метод с жестко закодированными шаблонами (для совместимости)
  def format_booking_notification_fallback(booking, type)
    # Получаем название сервиса - используем разные подходы в зависимости от доступных данных
    service_name = if booking.services.any?
                     booking.services.first.name
                   elsif booking.respond_to?(:service_category) && booking.service_category
                     booking.service_category.name
                   else
                     'Послуга шиномонтажу'
                   end
    
    point_name = booking.service_point&.name || 'Сервісна точка'
    date = booking.start_time&.strftime('%d.%m.%Y') || booking.booking_date&.strftime('%d.%m.%Y') || 'Не вказано'
    time = booking.start_time&.strftime('%H:%M') || 'Не вказано'

    case type
    when 'booking_confirmation'
      {
        title: 'Запис підтверджено!',
        body: "#{service_name} - #{date} о #{time}\n#{point_name}"
      }
    when 'booking_cancelled'
      {
        title: 'Запис скасовано',
        body: "#{service_name} - #{date} о #{time}\n#{point_name}"
      }
    when 'booking_reminder'
      {
        title: 'Нагадування про запис',
        body: "Завтра: #{service_name} - #{time}\n#{point_name}"
      }
    when 'service_completed'
      {
        title: 'Обслуговування завершено!',
        body: "#{service_name} - #{date}\n#{point_name}\nДякуємо за вибір!"
      }
    when 'review_request'
      {
        title: 'Оцініть наш сервіс!',
        body: "Як вам обслуговування: #{service_name}?\nЗалиште відгук на сайті"
      }
    else
      {
        title: 'Tire Service',
        body: "Оновлення бронювання #{service_name}"
      }
    end
  end
end 