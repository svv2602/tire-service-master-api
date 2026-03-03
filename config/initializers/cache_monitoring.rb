# frozen_string_literal: true

# Cache monitoring and metrics collection
# Logs cache hits/misses for performance analysis

module CacheMonitoring
  # Counters for cache statistics
  mattr_accessor :hits, default: 0
  mattr_accessor :misses, default: 0
  mattr_accessor :fetch_calls, default: 0

  # Reset counters
  def self.reset_stats!
    self.hits = 0
    self.misses = 0
    self.fetch_calls = 0
  end

  # Get current statistics
  def self.stats
    total = fetch_calls.positive? ? fetch_calls : 1
    {
      hits: hits,
      misses: misses,
      total_fetches: fetch_calls,
      hit_rate: (hits.to_f / total * 100).round(2),
      miss_rate: (misses.to_f / total * 100).round(2)
    }
  end

  # Log statistics to Rails logger
  def self.log_stats
    Rails.logger.info "[CacheMonitoring] #{stats.to_json}"
  end
end

# Subscribe to cache events only after Rails is fully initialized
Rails.application.config.after_initialize do
  ActiveSupport::Notifications.subscribe('cache_read.active_support') do |_name, _start, _finish, _id, payload|
    if payload[:hit]
      CacheMonitoring.hits += 1
    end
  end

  ActiveSupport::Notifications.subscribe('cache_fetch_hit.active_support') do |_name, _start, _finish, _id, _payload|
    CacheMonitoring.hits += 1
    CacheMonitoring.fetch_calls += 1
  end

  ActiveSupport::Notifications.subscribe('cache_generate.active_support') do |_name, start, finish, _id, payload|
    CacheMonitoring.misses += 1
    CacheMonitoring.fetch_calls += 1

    # Log slow cache generations (> 100ms)
    duration = (finish - start) * 1000
    if duration > 100
      Rails.logger.warn "[CacheMonitoring] Slow cache generation: #{payload[:key]} took #{duration.round(2)}ms"
    end
  end

  # Periodic cache stats logging is handled by CacheMonitoringJob (via cron).
  # The previous Thread.new approach was removed because threads spawned in
  # initializers are lost when Puma forks worker processes.
end
