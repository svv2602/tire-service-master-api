# frozen_string_literal: true

# Versioned cache keys pattern to avoid expensive delete_matched (O(n) SCAN in Redis).
# Instead of deleting all matching keys, we increment a version counter
# and include it in cache keys. Old entries expire naturally via TTL.
#
# Usage in models:
#   include CacheVersioning
#   after_commit :increment_cache_version
#
# Usage in controllers:
#   cache_key = CacheVersioning.versioned_key("cities:active", "cities")
#   Rails.cache.fetch(cache_key, expires_in: 24.hours) { ... }
#
module CacheVersioning
  extend ActiveSupport::Concern

  VERSION_KEY_PREFIX = "cache_version"

  class << self
    # Read current version for an entity type
    def cache_version(entity_type)
      Rails.cache.read("#{VERSION_KEY_PREFIX}:#{entity_type}") || 0
    end

    # Increment version, effectively invalidating all versioned keys for this entity type
    def increment_version(entity_type)
      key = "#{VERSION_KEY_PREFIX}:#{entity_type}"
      # Use increment if value exists, otherwise write initial version
      new_version = Rails.cache.increment(key)
      unless new_version
        Rails.cache.write(key, 1)
        new_version = 1
      end
      Rails.logger.info "[CacheVersioning] Incremented version for '#{entity_type}' to #{new_version}"
      new_version
    end

    # Build a versioned cache key
    def versioned_key(base_key, entity_type)
      version = cache_version(entity_type)
      "v#{version}/#{base_key}"
    end
  end

  # Instance method for models to call in after_commit
  def increment_cache_version
    entity_type = self.class.cache_entity_type
    CacheVersioning.increment_version(entity_type)
  end

  class_methods do
    # Override in model to customize the entity type string
    def cache_entity_type
      name.underscore.pluralize
    end
  end
end
