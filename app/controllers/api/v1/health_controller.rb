# frozen_string_literal: true

require 'open3'

module Api
  module V1
    # HealthController provides endpoints for infrastructure monitoring
    # Used by load balancers, uptime monitors, and deployment systems
    class HealthController < ApplicationController
      # Skip authentication for health checks
      skip_before_action :authenticate_request, only: [:index, :deep, :cache_stats]
      skip_after_action :verify_authorized

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
          connection_pool: check_connection_pool,
          redis: check_redis,
          sidekiq: check_sidekiq,
          elasticsearch: check_elasticsearch,
          openai: check_openai
        }

        # Determine overall status and HTTP code.
        # Only return 503 when critical services (database, redis) are down.
        # Non-critical services (sidekiq, openai) in warning/not_configured
        # state result in a degraded status with HTTP 200.
        critical_services = [:database, :redis]
        critical_down = critical_services.any? { |svc| checks[svc][:status] == 'error' }

        overall_status = if critical_down
                           'error'
                         elsif checks.values.all? { |c| c[:status] == 'ok' }
                           'ok'
                         else
                           'degraded'
                         end
        http_status = critical_down ? :service_unavailable : :ok

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

      # Check database connection pool usage (Phase-03)
      def check_connection_pool
        pool = ActiveRecord::Base.connection_pool
        stat = pool.stat

        usage_pct = stat[:busy].to_f / stat[:size] * 100

        {
          status: usage_pct > 90 ? 'warning' : 'ok',
          size: stat[:size],
          busy: stat[:busy],
          dead: stat[:dead],
          idle: stat[:idle],
          waiting: stat[:waiting],
          checkout_timeout: pool.checkout_timeout,
          usage_percent: usage_pct.round(1)
        }
      rescue StandardError => e
        Rails.logger.error "[Health] Connection pool check failed: #{e.message}"
        { status: 'error', error: e.message }
      end

      # Check Elasticsearch connectivity (Phase-03)
      def check_elasticsearch
        return { status: 'not_configured' } unless elasticsearch_configured?

        start_time = Time.current
        client = Elasticsearch::Model.client
        health = client.cluster.health
        latency_ms = ((Time.current - start_time) * 1000).round(2)

        {
          status: health['status'] == 'red' ? 'error' : 'ok',
          cluster_status: health['status'],
          number_of_nodes: health['number_of_nodes'],
          active_shards: health['active_shards'],
          latency_ms: latency_ms
        }
      rescue StandardError => e
        Rails.logger.warn "[Health] Elasticsearch check failed: #{e.message}"
        { status: 'warning', error: e.message }
      end

      def elasticsearch_configured?
        defined?(Elasticsearch::Model) && ENV['ELASTICSEARCH_URL'].present?
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

      # Check OpenAI API connectivity
      def check_openai
        return { status: 'not_configured' } unless ENV['OPENAI_API_KEY'].present?

        start_time = Time.current
        client = OpenAI::Client.new
        response = client.models.list
        latency_ms = ((Time.current - start_time) * 1000).round(2)

        {
          status: 'ok',
          models_available: response['data']&.length || 0,
          latency_ms: latency_ms
        }
      rescue StandardError => e
        Rails.logger.error "[Health] OpenAI check failed: #{e.message}"
        {
          status: 'error',
          error: e.message
        }
      end

      # Get application version from ENV, VERSION file, or git
      def app_version
        @app_version ||=
          ENV.fetch('APP_VERSION', nil) ||
          version_from_file ||
          git_revision ||
          'unknown'
      end

      def version_from_file
        version_file = Rails.root.join('VERSION')
        return nil unless File.exist?(version_file)

        File.read(version_file).strip.presence
      end

      def git_revision
        stdout, _status = Open3.capture2('git', 'rev-parse', '--short', 'HEAD')
        stdout.strip.presence
      rescue StandardError
        'unknown'
      end
    end
  end
end
