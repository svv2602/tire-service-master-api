class AuditLogJob < ApplicationJob
  queue_as :audit
  
  # Создание лога создания объекта
  def self.log_create(user_id:, resource_type:, resource_id:, new_value:, **options)
    perform_later(
      action: 'created',
      user_id: user_id,
      resource_type: resource_type,
      resource_id: resource_id,
      new_value: new_value,
      **options
    )
  end
  
  # Создание лога обновления объекта
  def self.log_update(user_id:, resource_type:, resource_id:, old_value:, new_value:, changes: nil, **options)
    perform_later(
      action: 'updated',
      user_id: user_id,
      resource_type: resource_type,
      resource_id: resource_id,
      old_value: old_value,
      new_value: new_value,
      changes: changes,
      **options
    )
  end
  
  # Создание лога удаления объекта
  def self.log_delete(user_id:, resource_type:, resource_id:, old_value:, **options)
    perform_later(
      action: 'deleted',
      user_id: user_id,
      resource_type: resource_type,
      resource_id: resource_id,
      old_value: old_value,
      **options
    )
  end
  
  # Создание лога блокировки пользователя
  def self.log_suspend(user_id:, target_user_id:, reason:, until_date: nil, **options)
    perform_later(
      action: 'suspended',
      user_id: user_id,
      resource_type: 'User',
      resource_id: target_user_id,
      additional_data: {
        reason: reason,
        until_date: until_date,
        suspended_at: Time.current
      },
      **options
    )
  end
  
  # Создание лога разблокировки пользователя
  def self.log_unsuspend(user_id:, target_user_id:, **options)
    perform_later(
      action: 'unsuspended',
      user_id: user_id,
      resource_type: 'User',
      resource_id: target_user_id,
      additional_data: {
        unsuspended_at: Time.current
      },
      **options
    )
  end
  
  # Создание лога назначения оператора
  def self.log_assignment(user_id:, operator_id:, service_point_ids:, **options)
    perform_later(
      action: 'assigned',
      user_id: user_id,
      resource_type: 'Operator',
      resource_id: operator_id,
      additional_data: {
        service_point_ids: service_point_ids,
        assigned_at: Time.current
      },
      **options
    )
  end
  
  # Создание лога отзыва назначения оператора
  def self.log_unassignment(user_id:, operator_id:, service_point_ids:, **options)
    perform_later(
      action: 'unassigned',
      user_id: user_id,
      resource_type: 'Operator',
      resource_id: operator_id,
      additional_data: {
        service_point_ids: service_point_ids,
        unassigned_at: Time.current
      },
      **options
    )
  end
  
  # Создание лога входа в систему
  def self.log_login(user_id:, **options)
    perform_later(
      action: 'login',
      user_id: user_id,
      additional_data: {
        login_at: Time.current
      },
      **options
    )
  end
  
  # Создание лога выхода из системы
  def self.log_logout(user_id:, **options)
    perform_later(
      action: 'logout',
      user_id: user_id,
      additional_data: {
        logout_at: Time.current
      },
      **options
    )
  end
  
  def perform(action:, user_id: nil, resource_type: nil, resource_id: nil, old_value: nil, new_value: nil, changes: nil, additional_data: nil, ip_address: nil, user_agent: nil, **options)
    # Находим пользователя
    user = user_id ? User.find_by(id: user_id) : nil
    
    # Создаем запись в логе
    SystemLog.create!(
      user: user,
      action: action,
      resource_type: resource_type,
      resource_id: resource_id,
      old_value: old_value,
      new_value: new_value,
      changes: changes,
      additional_data: additional_data,
      ip_address: ip_address,
      user_agent: user_agent
    )
    
    # Дополнительная логика для критичных событий
    handle_critical_events(action, user, resource_type, resource_id, additional_data)
    
  rescue => e
    # Логируем ошибку, но не прерываем выполнение
    Rails.logger.error "AuditLogJob failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    # Можно отправить уведомление администраторам о проблеме с аудитом
    # AdminNotificationService.notify_audit_failure(e) if Rails.env.production?
  end
  
  private
  
  def handle_critical_events(action, user, resource_type, resource_id, additional_data)
    case action
    when 'suspended'
      # Уведомляем администраторов о блокировке пользователя
      handle_user_suspension(user, resource_id, additional_data)
    when 'login'
      # Проверяем подозрительную активность при входе
      handle_login_monitoring(user, additional_data)
    when 'deleted'
      # Уведомляем о критичных удалениях
      handle_critical_deletion(user, resource_type, resource_id)
    end
  end
  
  def handle_user_suspension(user, target_user_id, additional_data)
    return unless Rails.env.production?
    
    # Уведомляем администраторов о блокировке
    AdminNotificationService.notify_user_suspended(
      suspended_by: user,
      target_user_id: target_user_id,
      reason: additional_data&.dig('reason'),
      until_date: additional_data&.dig('until_date')
    ) if defined?(AdminNotificationService)
  end
  
  def handle_login_monitoring(user, additional_data)
    return unless user
    
    # Проверяем частоту входов для выявления подозрительной активности
    recent_logins = SystemLog.where(
      user: user,
      action: 'login',
      created_at: 1.hour.ago..Time.current
    ).count
    
    if recent_logins > 10 # Подозрительно много входов за час
      AdminNotificationService.notify_suspicious_activity(
        user: user,
        activity_type: 'frequent_logins',
        count: recent_logins,
        ip_address: additional_data&.dig('ip_address')
      ) if defined?(AdminNotificationService)
    end
  end
  
  def handle_critical_deletion(user, resource_type, resource_id)
    # Уведомляем о удалении критичных ресурсов
    critical_resources = %w[User ServicePoint Partner]
    
    if critical_resources.include?(resource_type)
      AdminNotificationService.notify_critical_deletion(
        deleted_by: user,
        resource_type: resource_type,
        resource_id: resource_id
      ) if defined?(AdminNotificationService)
    end
  end
end 