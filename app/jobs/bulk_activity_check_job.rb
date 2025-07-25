class BulkActivityCheckJob < ApplicationJob
  queue_as :default
  
  # Проверка массовой активности пользователя
  def perform(user_id, since_time = 1.hour.ago)
    user = User.find_by(id: user_id)
    return unless user
    
    # Подсчитываем активность пользователя за последний час
    recent_activities = SystemLog.where(
      user_id: user_id,
      created_at: since_time..Time.current
    )
    
    changes_count = recent_activities.count
    
    # Пороги для уведомлений
    warning_threshold = 20
    critical_threshold = 50
    
    if changes_count >= critical_threshold
      send_bulk_changes_alert(user, changes_count, 'high')
    elsif changes_count >= warning_threshold
      send_bulk_changes_alert(user, changes_count, 'medium')
    end
    
    # Проверяем разнообразие типов ресурсов
    resource_types = recent_activities.distinct.pluck(:resource_type)
    if resource_types.size > 5 && changes_count > 15
      send_suspicious_behavior_alert(user, 'diverse_resource_access', {
        resource_types: resource_types,
        changes_count: changes_count,
        time_window: '1 час'
      })
    end
  end
  
  private
  
  def send_bulk_changes_alert(user, changes_count, severity)
    # Получаем затронутые ресурсы
    affected_resources = SystemLog.where(
      user_id: user.id,
      created_at: 1.hour.ago..Time.current
    ).group(:resource_type).count.map do |resource_type, count|
      "#{resource_type}: #{count}"
    end
    
    SecurityAlertJob.perform_later(
      'bulk_data_changes',
      user: user,
      changes_count: changes_count,
      time_window: '1 час',
      affected_resources: affected_resources,
      severity: severity
    )
  end
  
  def send_suspicious_behavior_alert(user, behavior_type, details)
    SecurityAlertJob.perform_later(
      'suspicious_user_behavior',
      user: user,
      behavior_type: behavior_type,
      details: details,
      severity: 'high'
    )
  end
end 