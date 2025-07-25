# Настройки кэширования для повышения производительности системы ролей и изоляции данных

Rails.application.configure do
  # Включаем фрагментное кэширование в development для тестирования
  if Rails.env.development?
    config.action_controller.perform_caching = true
    config.cache_store = :redis_cache_store, { url: ENV['REDIS_URL'] || 'redis://localhost:6379/1' }
  end
  
  # В production используем Redis для кэширования
  if Rails.env.production?
    config.cache_store = :redis_cache_store, { 
      url: ENV['REDIS_URL'],
      expires_in: 1.hour,
      namespace: 'tire_service_cache'
    }
  end
end

# Настройки кэширования для системы ролей
module RolesCacheConfig
  # Время жизни кэша для различных типов данных
  USER_PERMISSIONS_TTL = 5.minutes
  SERVICE_POINTS_TTL = 10.minutes
  POLICY_RESULTS_TTL = 2.minutes
  STATISTICS_TTL = 30.minutes
  
  # Ключи кэша
  def self.user_permissions_key(user_id)
    "user_permissions:#{user_id}"
  end
  
  def self.user_service_points_key(user_id, role)
    "user_service_points:#{user_id}:#{role}"
  end
  
  def self.policy_result_key(user_id, resource_type, resource_id, action)
    "policy:#{user_id}:#{resource_type}:#{resource_id}:#{action}"
  end
  
  def self.statistics_key(type, period = 'daily')
    "stats:#{type}:#{period}:#{Date.current}"
  end
end

# Автоматическая инвалидация кэша при изменении ролей
ActiveSupport::Notifications.subscribe('user_role_changed') do |name, start, finish, id, payload|
  user_id = payload[:user_id]
  
  # Очищаем кэш пользователя
  Rails.cache.delete(RolesCacheConfig.user_permissions_key(user_id))
  Rails.cache.delete_matched("user_service_points:#{user_id}:*")
  Rails.cache.delete_matched("policy:#{user_id}:*")
  
  Rails.logger.info "🗑️ Cache invalidated for user #{user_id} due to role change"
end

# Инвалидация кэша при изменении назначений операторов
ActiveSupport::Notifications.subscribe('operator_assignment_changed') do |name, start, finish, id, payload|
  operator_id = payload[:operator_id]
  user_id = payload[:user_id]
  
  if user_id
    Rails.cache.delete(RolesCacheConfig.user_permissions_key(user_id))
    Rails.cache.delete_matched("user_service_points:#{user_id}:*")
    Rails.cache.delete_matched("policy:#{user_id}:*")
    
    Rails.logger.info "🗑️ Cache invalidated for operator user #{user_id}"
  end
end 