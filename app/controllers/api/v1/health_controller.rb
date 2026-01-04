# frozen_string_literal: true

module Api
  module V1
    # HealthController provides endpoints for infrastructure monitoring
    # Used by load balancers, uptime monitors, and deployment systems
    class HealthController < ApplicationController
      # Skip authentication for health checks
      skip_before_action :authenticate_request, only: [:index, :deep, :cache_stats]

      # GET /api/v1/health
      # Basic liveness check - returns 200 if app is running
      def index
        render json: {
          status: 'ok',
          timestamp: Time.current.iso8601,
          environment: Rails.env
        }, status: :ok
      end

      # GET /api/v1/health/deep
      # Deep health check - verifies all critical dependencies
      def deep
        checks = {
          database: check_database,
          redis: check_redis,
          sidekiq: check_sidekiq
        }

        overall_status = checks.values.all? { |c| c[:status] == 'ok' } ? 'ok' : 'degraded'
        http_status = overall_status == 'ok' ? :ok : :service_unavailable

        render json: {
          status: overall_status,
          checks: checks,
          timestamp: Time.current.iso8601,
          version: app_version,
          environment: Rails.env
        }, status: http_status
      end

      # GET /api/v1/health/cache_stats
      # Returns cache monitoring statistics (admin only in production)
      def cache_stats
        # In production, require admin authentication
        if Rails.env.production? && !current_user&.admin?
          return render json: { error: 'Unauthorized' }, status: :unauthorized
        end

        stats = if defined?(CacheMonitoring)
                  CacheMonitoring.stats
                else
                  { message: 'Cache monitoring not initialized' }
                end

        render json: {
          cache_stats: stats,
          cache_store: Rails.cache.class.name,
          timestamp: Time.current.iso8601
        }
      end

      private

      # Check PostgreSQL database connectivity
      def check_database
        start_time = Time.current
        ActiveRecord::Base.connection.execute('SELECT 1')
        latency_ms = ((Time.current - start_time) * 1000).round(2)

        {
          status: 'ok',
          latency_ms: latency_ms
        }
      rescue StandardError => e
        Rails.logger.error "[Health] Database check failed: #{e.message}"
        {
          status: 'error',
          error: e.message
        }
      end

      # Check Redis connectivity
      def check_redis
        start_time = Time.current

        # Check if Redis is available through Rails.cache
        if Rails.cache.respond_to?(:redis)
          Rails.cache.redis.ping
        elsif defined?(Redis) && ENV['REDIS_URL']
          Redis.new(url: ENV['REDIS_URL']).ping
        else
          # Try to write and read from cache
          key = "health_check_#{SecureRandom.hex(4)}"
          Rails.cache.write(key, 'ok', expires_in: 5.seconds)
          result = Rails.cache.read(key)
          Rails.cache.delete(key)
          raise 'Cache write/read failed' unless result == 'ok'
        end

        latency_ms = ((Time.current - start_time) * 1000).round(2)

        {
          status: 'ok',
          latency_ms: latency_ms
        }
      rescue StandardError => e
        Rails.logger.error "[Health] Redis check failed: #{e.message}"
        {
          status: 'error',
          error: e.message
        }
      end

      # Check Sidekiq status
      def check_sidekiq
        return { status: 'not_configured' } unless defined?(Sidekiq)

        require 'sidekiq/api'

        stats = Sidekiq::Stats.new
        processes = Sidekiq::ProcessSet.new

        {
          status: processes.size.positive? ? 'ok' : 'warning',
          processes: processes.size,
          queues: Sidekiq::Queue.all.map { |q| { name: q.name, size: q.size } },
          stats: {
            processed: stats.processed,
            failed: stats.failed,
            enqueued: stats.enqueued,
            scheduled: stats.scheduled_size,
            retries: stats.retry_size,
            dead: stats.dead_size
          }
        }
      rescue StandardError => e
        Rails.logger.error "[Health] Sidekiq check failed: #{e.message}"
        {
          status: 'error',
          error: e.message
        }
      end

      # Get application version from git or environment
      def app_version
        ENV.fetch('APP_VERSION', nil) ||
          `git rev-parse --short HEAD 2>/dev/null`.strip.presence ||
          'unknown'
      end
    end
  end
end
