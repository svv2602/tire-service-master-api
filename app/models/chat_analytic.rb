# frozen_string_literal: true

# Tracks analytics for tire chat interactions
# Used for analyzing chat patterns, popular queries, and conversion rates
class ChatAnalytic < ApplicationRecord
  belongs_to :conversation, optional: true
  belongs_to :conversation_message, optional: true

  # Validations
  validates :session_id, presence: true
  validates :user_query, presence: true
  validates :response_type, presence: true

  # Response types
  RESPONSE_TYPES = %w[
    general
    product_recommendation
    brand_comparison
    size_selection
    seasonal_advice
    price_inquiry
    error
    fallback
  ].freeze

  validates :response_type, inclusion: { in: RESPONSE_TYPES }

  # Scopes
  scope :with_results, -> { where(had_results: true) }
  scope :without_results, -> { where(had_results: false) }
  scope :quick_questions, -> { where(is_quick_question: true) }
  scope :brand_comparisons, -> { where(is_brand_comparison: true) }
  scope :recent, ->(days = 7) { where('created_at >= ?', days.days.ago) }
  scope :by_intent, ->(intent) { where(intent: intent) }
  scope :by_response_type, ->(type) { where(response_type: type) }

  # Class methods for analytics
  class << self
    # Get popular queries with count
    # @param limit [Integer] number of results to return
    # @param days [Integer] number of days to look back
    # @return [Array<Hash>] array of {query:, count:}
    def popular_queries(limit: 20, days: 30)
      recent(days)
        .where.not(normalized_query: [nil, ''])
        .group(:normalized_query)
        .order('count_all DESC')
        .limit(limit)
        .count
        .map { |query, count| { query: query, count: count } }
    end

    # Get queries with no results
    # @param limit [Integer] number of results to return
    # @param days [Integer] number of days to look back
    # @return [Array<Hash>] array of {query:, count:}
    def no_results_queries(limit: 20, days: 30)
      without_results
        .recent(days)
        .where.not(normalized_query: [nil, ''])
        .group(:normalized_query)
        .order('count_all DESC')
        .limit(limit)
        .count
        .map { |query, count| { query: query, count: count } }
    end

    # Get conversion rate (queries with results / total queries)
    # @param days [Integer] number of days to look back
    # @return [Float] conversion rate as percentage
    def conversion_rate(days: 30)
      total = recent(days).count
      return 0.0 if total.zero?

      with_results = recent(days).with_results.count
      (with_results.to_f / total * 100).round(2)
    end

    # Get average response time
    # @param days [Integer] number of days to look back
    # @return [Float] average response time in ms
    def average_response_time(days: 30)
      recent(days)
        .where.not(response_time_ms: nil)
        .average(:response_time_ms)
        &.round(2) || 0.0
    end

    # Get intent distribution
    # @param days [Integer] number of days to look back
    # @return [Hash] intent => count
    def intent_distribution(days: 30)
      recent(days)
        .where.not(intent: [nil, ''])
        .group(:intent)
        .count
    end

    # Get response type distribution
    # @param days [Integer] number of days to look back
    # @return [Hash] response_type => count
    def response_type_distribution(days: 30)
      recent(days)
        .group(:response_type)
        .count
    end

    # Get hourly distribution
    # @param days [Integer] number of days to look back
    # @return [Hash] hour => count
    def hourly_distribution(days: 30)
      recent(days)
        .group("EXTRACT(HOUR FROM created_at)::integer")
        .count
        .transform_keys(&:to_i)
    end

    # Get daily stats
    # @param days [Integer] number of days to look back
    # @return [Array<Hash>] array of {date:, total:, with_results:, avg_response_time:}
    def daily_stats(days: 30)
      base_query = recent(days).group("DATE(created_at)")

      totals = base_query.count
      with_results = recent(days).with_results.group("DATE(created_at)").count
      avg_times = recent(days)
                  .where.not(response_time_ms: nil)
                  .group("DATE(created_at)")
                  .average(:response_time_ms)

      totals.keys.sort.map do |date|
        {
          date: date,
          total: totals[date] || 0,
          with_results: with_results[date] || 0,
          avg_response_time: avg_times[date]&.round(2) || 0.0
        }
      end
    end

    # Get summary stats
    # @param days [Integer] number of days to look back
    # @return [Hash] summary statistics
    def summary(days: 30)
      scope = recent(days)

      {
        total_queries: scope.count,
        queries_with_results: scope.with_results.count,
        queries_without_results: scope.without_results.count,
        quick_questions: scope.quick_questions.count,
        brand_comparisons: scope.brand_comparisons.count,
        conversion_rate: conversion_rate(days: days),
        avg_response_time_ms: average_response_time(days: days),
        total_products_shown: scope.sum(:products_count)
      }
    end
  end
end
