# frozen_string_literal: true

module Api
  module V1
    module Admin
      # Controller for AI usage monitoring and cost analytics
      # Phase-02: Admin dashboard for AI costs and quota management
      class AiUsageController < AdminController
        skip_after_action :verify_authorized

        # GET /api/v1/admin/ai_usage/summary
        # Returns overall AI usage statistics
        def summary
          days = params[:days]&.to_i || 30

          render json: {
            success: true,
            data: AiUsageLog.overall_stats(days: days),
            period_days: days,
            daily_budget: {
              limit_usd: ENV.fetch('AI_DAILY_BUDGET_USD', '10.0').to_f,
              spent_today_usd: AiUsageLog.todays_cost.round(4),
              exceeded: AiUsageLog.daily_budget_exceeded?
            }
          }
        end

        # GET /api/v1/admin/ai_usage/daily
        # Returns daily breakdown of AI usage
        def daily
          days = params[:days]&.to_i || 30

          daily_data = AiUsageLog.daily_summary(days: days).map do |row|
            {
              date: row.date,
              total_calls: row.total_calls,
              successful_calls: row.successful_calls,
              failed_calls: row.failed_calls,
              cached_calls: row.cached_calls,
              total_input_tokens: row.total_input_tokens,
              total_output_tokens: row.total_output_tokens,
              total_cost_usd: row.total_cost.to_f.round(4),
              avg_latency_ms: row.avg_latency_ms.to_f.round(2)
            }
          end

          render json: {
            success: true,
            data: daily_data,
            period_days: days
          }
        end

        # GET /api/v1/admin/ai_usage/by_service
        # Returns per-service breakdown
        def by_service
          days = params[:days]&.to_i || 30

          service_data = AiUsageLog.service_summary(days: days).map do |row|
            {
              service_name: row.service_name,
              total_calls: row.total_calls,
              successful_calls: row.successful_calls,
              total_input_tokens: row.total_input_tokens,
              total_output_tokens: row.total_output_tokens,
              total_cost_usd: row.total_cost.to_f.round(4),
              avg_latency_ms: row.avg_latency_ms.to_f.round(2)
            }
          end

          render json: {
            success: true,
            data: service_data,
            period_days: days
          }
        end

        # GET /api/v1/admin/ai_usage/top_users
        # Returns top users by AI cost
        def top_users
          days = params[:days]&.to_i || 30
          limit = params[:limit]&.to_i || 20

          users_data = AiUsageLog.top_users(days: days, limit: limit).map do |row|
            user = User.find_by(id: row.user_id)
            {
              user_id: row.user_id,
              email: user&.email,
              name: user&.name,
              role: user&.role,
              total_calls: row.total_calls,
              total_cost_usd: row.total_cost.to_f.round(4),
              total_tokens: row.total_tokens
            }
          end

          render json: {
            success: true,
            data: users_data,
            period_days: days
          }
        end

        # GET /api/v1/admin/ai_usage/quota_status
        # Returns current quota status and limits
        def quota_status
          render json: {
            success: true,
            data: AiQuotaService.usage_stats,
            wrapper_metrics: AiRequestWrapper.current_metrics
          }
        end

        # GET /api/v1/admin/ai_usage/cache_stats
        # Returns cache hit rate statistics
        def cache_stats
          stats = fetch_cache_metrics

          render json: {
            success: true,
            data: stats
          }
        end

        # POST /api/v1/admin/ai_usage/reset_user_quota
        # Reset quota for a specific user
        def reset_user_quota
          user_id = params[:user_id]

          unless user_id.present?
            return render json: { error: 'user_id is required' }, status: :bad_request
          end

          AiQuotaService.reset_user_quota!(user_id)
          log_admin_action('reset_user_quota', "User:#{user_id}")

          render json: {
            success: true,
            message: "Quota reset for user #{user_id}",
            new_usage: AiQuotaService.user_usage(user_id)
          }
        end

        private

        def fetch_cache_metrics
          redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'))
          stats = {}

          # Get last 7 days of cache metrics
          7.times do |i|
            date = (Date.current - i.days).to_s
            key = "tire_search_cache_metrics:#{date}"
            hits = redis.hget(key, 'hits').to_i
            misses = redis.hget(key, 'misses').to_i
            total = hits + misses
            hit_rate = total > 0 ? (hits.to_f / total * 100).round(2) : 0

            stats[date] = {
              hits: hits,
              misses: misses,
              total: total,
              hit_rate: hit_rate
            }
          end

          stats
        rescue Redis::BaseError => e
          Rails.logger.warn "[AiUsageController] Redis error: #{e.message}"
          {}
        end
      end
    end
  end
end
