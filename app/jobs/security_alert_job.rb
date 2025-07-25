class SecurityAlertJob < ApplicationJob
  queue_as :default

  # Отправка уведомления о подозрительной активности
  def perform(alert_type, data = {})
    case alert_type.to_s
    when 'frequent_failed_logins'
      send_failed_login_alert(data)
    when 'multiple_ip_access'
      send_multiple_ip_alert(data)
    when 'bulk_data_changes'
      send_bulk_changes_alert(data)
    when 'off_hours_activity'
      send_off_hours_alert(data)
    when 'suspicious_user_behavior'
      send_suspicious_behavior_alert(data)
    else
      Rails.logger.warn "Неизвестный тип алерта безопасности: #{alert_type}"
    end
  end

  private

  def send_failed_login_alert(data)
    ip_address = data[:ip_address]
    attempts_count = data[:attempts_count]
    time_window = data[:time_window] || '1 час'
    
    admin_emails = get_admin_emails
    
    admin_emails.each do |email|
      SecurityMailer.failed_login_alert(
        email: email,
        ip_address: ip_address,
        attempts_count: attempts_count,
        time_window: time_window,
        timestamp: Time.current
      ).deliver_now
    end
    
    Rails.logger.info "Отправлено уведомление о множественных неудачных попытках входа с IP #{ip_address}"
  end

  def send_multiple_ip_alert(data)
    user = data[:user]
    ip_addresses = data[:ip_addresses]
    time_window = data[:time_window] || '24 часа'
    
    admin_emails = get_admin_emails
    
    admin_emails.each do |email|
      SecurityMailer.multiple_ip_alert(
        email: email,
        user: user,
        ip_addresses: ip_addresses,
        time_window: time_window,
        timestamp: Time.current
      ).deliver_now
    end
    
    Rails.logger.info "Отправлено уведомление о входе пользователя #{user.email} с множественных IP"
  end

  def send_bulk_changes_alert(data)
    user = data[:user]
    changes_count = data[:changes_count]
    time_window = data[:time_window] || '1 час'
    affected_resources = data[:affected_resources] || []
    
    admin_emails = get_admin_emails
    
    admin_emails.each do |email|
      SecurityMailer.bulk_changes_alert(
        email: email,
        user: user,
        changes_count: changes_count,
        time_window: time_window,
        affected_resources: affected_resources,
        timestamp: Time.current
      ).deliver_now
    end
    
    Rails.logger.info "Отправлено уведомление о массовых изменениях пользователем #{user.email}"
  end

  def send_off_hours_alert(data)
    user = data[:user]
    action = data[:action]
    resource = data[:resource]
    timestamp = data[:timestamp] || Time.current
    
    admin_emails = get_admin_emails
    
    admin_emails.each do |email|
      SecurityMailer.off_hours_alert(
        email: email,
        user: user,
        action: action,
        resource: resource,
        timestamp: timestamp
      ).deliver_now
    end
    
    Rails.logger.info "Отправлено уведомление о внерабочей активности пользователя #{user.email}"
  end

  def send_suspicious_behavior_alert(data)
    user = data[:user]
    behavior_type = data[:behavior_type]
    details = data[:details] || {}
    severity = data[:severity] || 'medium'
    
    # Отправляем только высокоприоритетные алерты
    return unless severity == 'high'
    
    admin_emails = get_admin_emails
    
    admin_emails.each do |email|
      SecurityMailer.suspicious_behavior_alert(
        email: email,
        user: user,
        behavior_type: behavior_type,
        details: details,
        severity: severity,
        timestamp: Time.current
      ).deliver_now
    end
    
    Rails.logger.info "Отправлено уведомление о подозрительном поведении пользователя #{user.email}"
  end

  def get_admin_emails
    # Получаем email всех администраторов
    admin_emails = User.joins(:user_roles)
                      .where(user_roles: { role: 'admin' })
                      .where(is_active: true)
                      .pluck(:email)
    
    # Если нет активных админов, используем системный email
    if admin_emails.empty?
      admin_emails = [Rails.application.credentials.dig(:admin_email) || 'admin@example.com']
    end
    
    admin_emails
  end
end 