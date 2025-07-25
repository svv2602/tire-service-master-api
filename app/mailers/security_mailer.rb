class SecurityMailer < ApplicationMailer
  default from: Rails.application.credentials.dig(:email, :from) || 'security@tire-service.com'

  # Уведомление о множественных неудачных попытках входа
  def failed_login_alert(email:, ip_address:, attempts_count:, time_window:, timestamp:)
    @ip_address = ip_address
    @attempts_count = attempts_count
    @time_window = time_window
    @timestamp = timestamp
    @severity = attempts_count > 10 ? 'КРИТИЧНО' : 'ВНИМАНИЕ'
    
    mail(
      to: email,
      subject: "🚨 #{@severity}: Множественные неудачные попытки входа"
    )
  end

  # Уведомление о входе с множественных IP адресов
  def multiple_ip_alert(email:, user:, ip_addresses:, time_window:, timestamp:)
    @user = user
    @ip_addresses = ip_addresses
    @time_window = time_window
    @timestamp = timestamp
    @severity = ip_addresses.size > 5 ? 'КРИТИЧНО' : 'ВНИМАНИЕ'
    
    mail(
      to: email,
      subject: "🚨 #{@severity}: Вход пользователя с множественных IP адресов"
    )
  end

  # Уведомление о массовых изменениях данных
  def bulk_changes_alert(email:, user:, changes_count:, time_window:, affected_resources:, timestamp:)
    @user = user
    @changes_count = changes_count
    @time_window = time_window
    @affected_resources = affected_resources
    @timestamp = timestamp
    @severity = changes_count > 50 ? 'КРИТИЧНО' : 'ВНИМАНИЕ'
    
    mail(
      to: email,
      subject: "🚨 #{@severity}: Массовые изменения данных пользователем"
    )
  end

  # Уведомление о активности в нерабочее время
  def off_hours_alert(email:, user:, action:, resource:, timestamp:)
    @user = user
    @action = action
    @resource = resource
    @timestamp = timestamp
    @hour = timestamp.hour
    @severity = is_critical_action?(action) ? 'КРИТИЧНО' : 'ВНИМАНИЕ'
    
    mail(
      to: email,
      subject: "🚨 #{@severity}: Активность в нерабочее время"
    )
  end

  # Уведомление о подозрительном поведении
  def suspicious_behavior_alert(email:, user:, behavior_type:, details:, severity:, timestamp:)
    @user = user
    @behavior_type = behavior_type
    @details = details
    @severity = severity.upcase == 'HIGH' ? 'КРИТИЧНО' : 'ВНИМАНИЕ'
    @timestamp = timestamp
    
    mail(
      to: email,
      subject: "🚨 #{@severity}: Подозрительное поведение пользователя"
    )
  end

  private

  def is_critical_action?(action)
    critical_actions = %w[
      deleted
      suspended
      role_changed
      permissions_changed
      system_settings_changed
    ]
    
    critical_actions.include?(action.to_s)
  end
end 