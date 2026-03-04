# frozen_string_literal: true

module Api
  module V1
    module Admin
      # Controller for chat analytics dashboard
      # Provides statistics and insights about tire chat usage
      class ChatAnalyticsController < AdminController
      skip_after_action :verify_authorized
        # Authentication and admin check inherited from AdminController

        # GET /api/v1/admin/chat_analytics/summary
        # Returns summary statistics for chat analytics
        def summary
          days = params[:days]&.to_i || 30

          render json: {
            success: true,
            data: TireChat::AnalyticsService.summary(days: days),
            period_days: days
          }
        end

        # GET /api/v1/admin/chat_analytics/popular_queries
        # Returns most popular user queries
        def popular_queries
          limit = params[:limit]&.to_i || 20
          days = params[:days]&.to_i || 30

          render json: {
            success: true,
            data: TireChat::AnalyticsService.popular_queries(limit: limit, days: days),
            period_days: days
          }
        end

        # GET /api/v1/admin/chat_analytics/no_results_queries
        # Returns queries that had no results
        def no_results_queries
          limit = params[:limit]&.to_i || 20
          days = params[:days]&.to_i || 30

          render json: {
            success: true,
            data: TireChat::AnalyticsService.no_results_queries(limit: limit, days: days),
            period_days: days
          }
        end

        # GET /api/v1/admin/chat_analytics/intent_distribution
        # Returns distribution of detected intents
        def intent_distribution
          days = params[:days]&.to_i || 30

          render json: {
            success: true,
            data: TireChat::AnalyticsService.intent_distribution(days: days),
            period_days: days
          }
        end

        # GET /api/v1/admin/chat_analytics/daily_stats
        # Returns daily breakdown of statistics
        def daily_stats
          days = params[:days]&.to_i || 30

          render json: {
            success: true,
            data: TireChat::AnalyticsService.daily_stats(days: days),
            period_days: days
          }
        end

        # GET /api/v1/admin/chat_analytics/hourly_distribution
        # Returns hourly distribution of queries
        def hourly_distribution
          days = params[:days]&.to_i || 30

          render json: {
            success: true,
            data: TireChat::AnalyticsService.hourly_distribution(days: days),
            period_days: days
          }
        end

        # GET /api/v1/admin/chat_analytics/response_type_distribution
        # Returns distribution of response types
        def response_type_distribution
          days = params[:days]&.to_i || 30

          render json: {
            success: true,
            data: ChatAnalytic.response_type_distribution(days: days),
            period_days: days
          }
        end

        # Admin authorization inherited from AdminController (ensure_admin! before_action)
      end
    end
  end
end
