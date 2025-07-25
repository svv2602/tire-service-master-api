module CacheablePolicy
  extend ActiveSupport::Concern
  
  # Кэширование результатов проверки политик
  def cached_policy_check(action, resource = nil)
    return yield unless Rails.cache.respond_to?(:fetch) && user.present?
    
    # Генерируем ключ кэша
    resource_key = resource.respond_to?(:cache_key) ? resource.cache_key : 
                   resource.is_a?(Class) ? resource.name : 
                   "#{resource.class.name}:#{resource.id}"
    
    cache_key = RolesCacheConfig.policy_result_key(
      user.id, 
      resource_key, 
      nil, 
      action.to_s
    )
    
    # Кэшируем результат на короткое время
    Rails.cache.fetch(cache_key, expires_in: RolesCacheConfig.POLICY_RESULTS_TTL) do
      yield
    end
  end
  
  # Кэширование scope результатов
  def cached_scope_resolve(scope_class, base_scope)
    return yield unless Rails.cache.respond_to?(:fetch) && user.present?
    
    # Для scope'ов кэшируем только ID записей, не сами объекты
    cache_key = "scope:#{user.id}:#{scope_class.name}:#{user.updated_at.to_i}"
    
    cached_ids = Rails.cache.fetch(cache_key, expires_in: RolesCacheConfig.POLICY_RESULTS_TTL) do
      yield.pluck(:id)
    end
    
    # Возвращаем scope с найденными ID
    base_scope.where(id: cached_ids)
  end
  
  # Инвалидация кэша для конкретного пользователя
  def invalidate_policy_cache!(user_id = nil)
    target_user_id = user_id || user&.id
    return unless target_user_id
    
    Rails.cache.delete_matched("policy:#{target_user_id}:*")
    Rails.cache.delete_matched("scope:#{target_user_id}:*")
    
    Rails.logger.info "🗑️ Policy cache invalidated for user #{target_user_id}"
  end
  
  class_methods do
    # Массовая инвалидация кэша для группы пользователей
    def invalidate_cache_for_users(user_ids)
      user_ids.each do |user_id|
        Rails.cache.delete_matched("policy:#{user_id}:*")
        Rails.cache.delete_matched("scope:#{user_id}:*")
      end
      
      Rails.logger.info "🗑️ Policy cache invalidated for #{user_ids.size} users"
    end
    
    # Инвалидация кэша при изменении ресурса
    def invalidate_cache_for_resource(resource)
      resource_key = resource.respond_to?(:cache_key) ? resource.cache_key : 
                     "#{resource.class.name}:#{resource.id}"
      
      Rails.cache.delete_matched("policy:*:#{resource_key}:*")
      
      Rails.logger.info "🗑️ Policy cache invalidated for resource #{resource_key}"
    end
  end
end

# Автоматическая интеграция с политиками
module PolicyCacheIntegration
  extend ActiveSupport::Concern
  
  included do
    include CacheablePolicy
    
    # Переопределяем основные методы с кэшированием
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