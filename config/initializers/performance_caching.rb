# Performance caching configuration for role system and data isolation
# NOTE: cache_store is configured in config/environments/*.rb (not here) to avoid duplication.

Rails.application.configure do
  # Enable fragment caching in development for testing purposes
  if Rails.env.development?
    config.action_controller.perform_caching = true
    config.cache_store = :redis_cache_store, { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1') }
  end
end

# Cache configuration for role system
module RolesCacheConfig
  # TTL for different data types
  USER_PERMISSIONS_TTL = 5.minutes
  SERVICE_POINTS_TTL = 10.minutes
  POLICY_RESULTS_TTL = 2.minutes
  STATISTICS_TTL = 30.minutes

  # Cache keys
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

# Automatic cache invalidation on role changes
# Uses versioned keys + direct key deletion instead of O(n) delete_matched
ActiveSupport::Notifications.subscribe('user_role_changed') do |name, start, finish, id, payload|
  user_id = payload[:user_id]

  # Delete specific per-user cache keys (O(1) operations)
  Rails.cache.delete(RolesCacheConfig.user_permissions_key(user_id))

  # Increment version counters to invalidate all versioned user keys
  CacheVersioning.increment_version("user_service_points:#{user_id}")
  CacheVersioning.increment_version("user_policies:#{user_id}")

  Rails.logger.info "[Cache] Versioned cache invalidated for user #{user_id} due to role change"
end

# Cache invalidation on operator assignment changes
ActiveSupport::Notifications.subscribe('operator_assignment_changed') do |name, start, finish, id, payload|
  operator_id = payload[:operator_id]
  user_id = payload[:user_id]

  if user_id
    # Delete specific per-user cache keys (O(1) operations)
    Rails.cache.delete(RolesCacheConfig.user_permissions_key(user_id))

    # Increment version counters to invalidate all versioned user keys
    CacheVersioning.increment_version("user_service_points:#{user_id}")
    CacheVersioning.increment_version("user_policies:#{user_id}")

    Rails.logger.info "[Cache] Versioned cache invalidated for operator user #{user_id}"
  end
end
