module CacheablePolicy
  extend ActiveSupport::Concern

  # Cache policy check results using versioned keys
  def cached_policy_check(action, resource = nil)
    return yield unless Rails.cache.respond_to?(:fetch) && user.present?

    # Build cache key with version to avoid delete_matched
    resource_key = resource.respond_to?(:cache_key) ? resource.cache_key :
                   resource.is_a?(Class) ? resource.name :
                   "#{resource.class.name}:#{resource.id}"

    version = CacheVersioning.cache_version("user_policies:#{user.id}")
    cache_key = "v#{version}/policy:#{user.id}:#{resource_key}:#{action}"

    # Cache result for a short time
    Rails.cache.fetch(cache_key, expires_in: RolesCacheConfig::POLICY_RESULTS_TTL) do
      yield
    end
  end

  # Cache scope results using versioned keys
  def cached_scope_resolve(scope_class, base_scope)
    return yield unless Rails.cache.respond_to?(:fetch) && user.present?

    # Build versioned scope cache key
    version = CacheVersioning.cache_version("user_policies:#{user.id}")
    cache_key = "v#{version}/scope:#{user.id}:#{scope_class.name}:#{user.updated_at.to_i}"

    cached_ids = Rails.cache.fetch(cache_key, expires_in: RolesCacheConfig::POLICY_RESULTS_TTL) do
      yield.pluck(:id)
    end

    # Return scope with found IDs
    base_scope.where(id: cached_ids)
  end

  # Invalidate cache for a specific user using versioned keys (O(1) instead of O(n))
  def invalidate_policy_cache!(user_id = nil)
    target_user_id = user_id || user&.id
    return unless target_user_id

    CacheVersioning.increment_version("user_policies:#{target_user_id}")

    Rails.logger.info "[Cache] Policy cache version incremented for user #{target_user_id}"
  end

  class_methods do
    # Bulk cache invalidation for a group of users
    def invalidate_cache_for_users(user_ids)
      user_ids.each do |user_id|
        CacheVersioning.increment_version("user_policies:#{user_id}")
      end

      Rails.logger.info "[Cache] Policy cache version incremented for #{user_ids.size} users"
    end

    # Invalidate cache when a resource changes
    def invalidate_cache_for_resource(resource)
      resource_key = resource.respond_to?(:cache_key) ? resource.cache_key :
                     "#{resource.class.name}:#{resource.id}"

      # Increment a resource-specific version counter
      CacheVersioning.increment_version("policy_resource:#{resource_key}")

      Rails.logger.info "[Cache] Policy cache version incremented for resource #{resource_key}"
    end
  end
end

# Automatic integration with policies
module PolicyCacheIntegration
  extend ActiveSupport::Concern

  included do
    include CacheablePolicy

    # Override main methods with caching
    def index?
      cached_policy_check(:index, record.class) { super }
    end

    def show?
      cached_policy_check(:show, record) { super }
    end

    def create?
      cached_policy_check(:create, record.class) { super }
    end

    def update?
      cached_policy_check(:update, record) { super }
    end

    def destroy?
      cached_policy_check(:destroy, record) { super }
    end
  end

  class Scope
    include CacheablePolicy

    def resolve
      cached_scope_resolve(self.class, scope) { super }
    end
  end
end
