# frozen_string_literal: true

# AiUsageLog - Tracks AI API usage for cost monitoring
#
# Phase-02: Records every AI call with token usage, cost, latency
#
# Attributes:
#   user_id        - authenticated user (nullable for anonymous)
#   service_name   - which AI service was called (tire_search, tire_chat, etc.)
#   operation      - specific operation name
#   tokens_input   - input tokens consumed
#   tokens_output  - output tokens consumed
#   model          - AI model used (e.g. gpt-4.1-mini)
#   cost_estimate  - estimated cost in USD
#   latency_ms     - request latency in milliseconds
#   attempts       - number of retry attempts
#   success        - whether the call succeeded
#   from_cache     - whether result was served from cache
#   error_message  - error details if failed
#   ip_address     - client IP for anonymous users
#   metadata       - additional JSON data
#
class AiUsageLog < ApplicationRecord
  belongs_to :user, optional: true

  validates :service_name, presence: true
  validates :operation, presence: true

  # Pricing per 1M tokens (approximate, configurable)
  MODEL_PRICING = {
    'gpt-4.1-mini' => { input: 0.40, output: 1.60 },
    'gpt-4o-mini' => { input: 0.15, output: 0.60 },
    'gpt-4o' => { input: 2.50, output: 10.00 },
    'gpt-4.1' => { input: 2.00, output: 8.00 },
    'gpt-4-turbo' => { input: 10.00, output: 30.00 },
    'gpt-3.5-turbo' => { input: 0.50, output: 1.50 }
  }.freeze

  # Default pricing if model not found
  DEFAULT_PRICING = { input: 1.00, output: 3.00 }.freeze

  # Scopes
  scope :successful, -> { where(success: true) }
  scope :failed, -> { where(success: false) }
  scope :cached, -> { where(from_cache: true) }
  scope :not_cached, -> { where(from_cache: false) }
  scope :by_service, ->(name) { where(service_name: name) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_date_range, ->(from, to) { where(created_at: from..to) }
  scope :today, -> { where(created_at: Date.current.all_day) }
  scope :this_week, -> { where(created_at: Date.current.beginning_of_week..Date.current.end_of_week) }
  scope :this_month, -> { where(created_at: Date.current.beginning_of_month..Date.current.end_of_month) }

  # Calculate cost estimate based on model pricing
  before_save :calculate_cost_estimate, if: :should_calculate_cost?

  # === Class methods for analytics ===

  # Daily summary stats
  def self.daily_summary(days: 30)
    where(created_at: days.days.ago..)
      .group("DATE(created_at)")
      .select(
        "DATE(created_at) as date",
        "COUNT(*) as total_calls",
        "COUNT(CASE WHEN success = true THEN 1 END) as successful_calls",
        "COUNT(CASE WHEN success = false THEN 1 END) as failed_calls",
        "COUNT(CASE WHEN from_cache = true THEN 1 END) as cached_calls",
        "SUM(tokens_input) as total_input_tokens",
        "SUM(tokens_output) as total_output_tokens",
        "SUM(cost_estimate) as total_cost",
        "AVG(latency_ms) as avg_latency_ms"
      )
      .order("date DESC")
  end

  # Per-service summary
  def self.service_summary(days: 30)
    where(created_at: days.days.ago..)
      .group(:service_name)
      .select(
        "service_name",
        "COUNT(*) as total_calls",
        "COUNT(CASE WHEN success = true THEN 1 END) as successful_calls",
        "SUM(tokens_input) as total_input_tokens",
        "SUM(tokens_output) as total_output_tokens",
        "SUM(cost_estimate) as total_cost",
        "AVG(latency_ms) as avg_latency_ms"
      )
      .order("total_calls DESC")
  end

  # Per-user summary (top users by cost)
  def self.top_users(days: 30, limit: 20)
    where(created_at: days.days.ago..)
      .where.not(user_id: nil)
      .group(:user_id)
      .select(
        "user_id",
        "COUNT(*) as total_calls",
        "SUM(cost_estimate) as total_cost",
        "SUM(tokens_input + tokens_output) as total_tokens"
      )
      .order("total_cost DESC")
      .limit(limit)
  end

  # Overall statistics
  def self.overall_stats(days: 30)
    scope = where(created_at: days.days.ago..)
    {
      total_calls: scope.count,
      successful_calls: scope.successful.count,
      failed_calls: scope.failed.count,
      cached_calls: scope.cached.count,
      cache_hit_rate: scope.count > 0 ? (scope.cached.count.to_f / scope.count * 100).round(2) : 0,
      total_input_tokens: scope.sum(:tokens_input),
      total_output_tokens: scope.sum(:tokens_output),
      total_cost_usd: scope.sum(:cost_estimate).to_f.round(4),
      avg_latency_ms: scope.average(:latency_ms)&.round(2) || 0,
      unique_users: scope.where.not(user_id: nil).distinct.count(:user_id)
    }
  end

  # Today's budget check
  def self.todays_cost
    today.sum(:cost_estimate).to_f
  end

  # Check if daily budget exceeded
  def self.daily_budget_exceeded?(daily_budget_usd = nil)
    budget = daily_budget_usd || ENV.fetch('AI_DAILY_BUDGET_USD', '10.0').to_f
    todays_cost >= budget
  end

  private

  def should_calculate_cost?
    cost_estimate.blank? || cost_estimate.zero?
  end

  def calculate_cost_estimate
    return unless model.present? && (tokens_input.to_i > 0 || tokens_output.to_i > 0)

    pricing = MODEL_PRICING[model] || DEFAULT_PRICING
    input_cost = (tokens_input.to_i / 1_000_000.0) * pricing[:input]
    output_cost = (tokens_output.to_i / 1_000_000.0) * pricing[:output]
    self.cost_estimate = (input_cost + output_cost).round(6)
  end
end
