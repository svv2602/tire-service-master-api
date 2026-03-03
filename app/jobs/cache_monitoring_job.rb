# frozen_string_literal: true

# CacheMonitoringJob -- periodically logs cache hit/miss statistics
# and resets counters.  Replaces the Thread.new anti-pattern that was
# previously in config/initializers/cache_monitoring.rb.
class CacheMonitoringJob < ApplicationJob
  queue_as :schedules

  def perform
    return unless defined?(CacheMonitoring)

    CacheMonitoring.log_stats
    CacheMonitoring.reset_stats!
  end
end
