# frozen_string_literal: true

module TireChat
  # Service for tracking and analyzing tire chat interactions
  # Provides methods for recording analytics and generating reports
  class AnalyticsService
    # Normalize query for grouping similar queries
    # @param query [String] the raw user query
    # @return [String] normalized query
    def self.normalize_query(query)
      return nil if query.blank?

      query.downcase
           .gsub(/[^\p{L}\p{N}\s]/u, ' ') # Remove special chars
           .gsub(/\s+/, ' ')              # Collapse whitespace
           .strip
           .truncate(255)
    end

    # Detect intent from query
    # @param query [String] the user query
    # @return [String] detected intent
    def self.detect_intent(query)
      return nil if query.blank?

      normalized = query.downcase

      case normalized
      when /зимн|winter|snow|лед|ice|холод|мороз/
        'winter_tires'
      when /летн|summer|теплый|жар/
        'summer_tires'
      when /всесезон|all.?season/
        'all_season_tires'
      when /размер|size|\d{3}\/\d{2}/
        'size_selection'
      when /сравн|vs|против|или|compare/
        'brand_comparison'
      when /цен|price|стоим|стоят|дешев|дорог|бюджет|эконом|сколько/
        'price_inquiry'
      when /порекоменд|посовет|помог|подобр|выбр/
        'recommendation'
      when /автомобил|машин|авто|car|vehicle/
        'car_specific'
      else
        'general'
      end
    end

    # Track a message interaction
    # @param params [Hash] tracking parameters
    # @option params [String] :session_id (required)
    # @option params [String] :user_query (required)
    # @option params [Conversation] :conversation
    # @option params [ConversationMessage] :message
    # @option params [String] :response_type
    # @option params [Array<Hash>] :products_shown
    # @option params [Integer] :response_time_ms
    # @option params [Boolean] :is_quick_question
    # @option params [Boolean] :is_brand_comparison
    # @option params [Hash] :filters_used
    # @option params [Hash] :metadata
    # @return [ChatAnalytic] the created record
    def self.track_message(params)
      user_query = params[:user_query]
      products = params[:products_shown] || []

      ChatAnalytic.create!(
        session_id: params[:session_id],
        conversation: params[:conversation],
        conversation_message: params[:message],
        user_query: user_query,
        normalized_query: normalize_query(user_query),
        intent: params[:intent] || detect_intent(user_query),
        response_type: params[:response_type] || 'general',
        products_shown: products.map { |p| p.is_a?(Hash) ? p[:id] || p['id'] : p }.compact,
        products_count: products.size,
        response_time_ms: params[:response_time_ms],
        had_results: products.any?,
        is_quick_question: params[:is_quick_question] || false,
        is_brand_comparison: params[:is_brand_comparison] || false,
        filters_used: params[:filters_used] || {},
        metadata: params[:metadata] || {}
      )
    rescue StandardError => e
      Rails.logger.error "[TireChat::AnalyticsService] Failed to track message: #{e.message}"
      nil
    end

    # Get popular queries
    # @param limit [Integer] number of results
    # @param days [Integer] days to look back
    # @return [Array<Hash>] popular queries with counts
    def self.popular_queries(limit: 20, days: 30)
      ChatAnalytic.popular_queries(limit: limit, days: days)
    end

    # Get queries without results
    # @param limit [Integer] number of results
    # @param days [Integer] days to look back
    # @return [Array<Hash>] no-result queries with counts
    def self.no_results_queries(limit: 20, days: 30)
      ChatAnalytic.no_results_queries(limit: limit, days: days)
    end

    # Get conversion rate
    # @param days [Integer] days to look back
    # @return [Float] conversion rate percentage
    def self.conversion_rate(days: 30)
      ChatAnalytic.conversion_rate(days: days)
    end

    # Get average response time
    # @param days [Integer] days to look back
    # @return [Float] average time in ms
    def self.average_response_time(days: 30)
      ChatAnalytic.average_response_time(days: days)
    end

    # Get summary statistics
    # @param days [Integer] days to look back
    # @return [Hash] summary stats
    def self.summary(days: 30)
      ChatAnalytic.summary(days: days)
    end

    # Get intent distribution
    # @param days [Integer] days to look back
    # @return [Hash] intent => count
    def self.intent_distribution(days: 30)
      ChatAnalytic.intent_distribution(days: days)
    end

    # Get daily statistics
    # @param days [Integer] days to look back
    # @return [Array<Hash>] daily stats
    def self.daily_stats(days: 30)
      ChatAnalytic.daily_stats(days: days)
    end

    # Get hourly distribution
    # @param days [Integer] days to look back
    # @return [Hash] hour => count
    def self.hourly_distribution(days: 30)
      ChatAnalytic.hourly_distribution(days: days)
    end
  end
end
