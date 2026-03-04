# frozen_string_literal: true

# AiRequestWrapper - Resilience wrapper for AI/OpenAI API calls
#
# Provides:
#   - Retry with exponential backoff (3 attempts, 2^n seconds)
#   - Circuit breaker pattern (5 failures -> 60 sec cooldown)
#   - Error classification and handling
#   - Metrics tracking (success/failure/retry counts, avg latency)
#   - Structured logging for each attempt
#   - AI usage logging to database (Phase-02)
#
# Usage:
#   result = AiRequestWrapper.call(operation: 'tire_search') do
#     OpenaiService.new.parse_tire_search_query(query)
#   end
#
#   # With usage logging (Phase-02):
#   result = AiRequestWrapper.call(
#     operation: 'tire_search_llm_parsing',
#     service_name: 'tire_search',
#     user: current_user,
#     ip_address: request.remote_ip,
#     model: 'gpt-4.1-mini'
#   ) do
#     OpenaiService.new.parse_tire_search_query(query)
#   end
#
#   result.success?    # => true/false
#   result.data        # => response data (nil on failure)
#   result.error       # => error message (nil on success)
#   result.fallback?   # => true if circuit is open
#
class AiRequestWrapper
  # Result object for consistent return values
  Result = Struct.new(:data, :error, :success, :fallback, :attempts, :latency_ms, keyword_init: true) do
    def success?
      success == true
    end

    def fallback?
      fallback == true
    end
  end

  # Configuration constants
  MAX_RETRIES = 3
  BASE_DELAY = 2 # seconds, used as 2^n for exponential backoff
  CIRCUIT_FAILURE_THRESHOLD = 5
  CIRCUIT_COOLDOWN_SECONDS = 60

  # Errors that should trigger retry
  RETRYABLE_ERRORS = [
    Timeout::Error,
    Net::ReadTimeout,
    Net::OpenTimeout,
    Faraday::TimeoutError,
    Faraday::ConnectionFailed,
    Errno::ECONNREFUSED,
    Errno::ECONNRESET,
    Errno::ETIMEDOUT
  ].freeze

  # Class-level circuit breaker state (shared across all instances)
  @circuit_state = :closed    # :closed, :open, :half_open
  @failure_count = 0
  @last_failure_time = nil
  @circuit_mutex = Mutex.new

  # Class-level metrics
  @metrics = {
    success_count: 0,
    failure_count: 0,
    retry_count: 0,
    total_latency_ms: 0,
    total_calls: 0
  }
  @metrics_mutex = Mutex.new

  class << self
    attr_reader :circuit_state, :failure_count, :last_failure_time, :metrics

    # Main entry point - wraps an AI API call with resilience
    #
    # @param operation [String] Name of the operation for logging
    # @param max_retries [Integer] Maximum retry attempts (default: 3)
    # @param service_name [String] Service name for usage logging (Phase-02)
    # @param user [User, nil] User for usage logging (Phase-02)
    # @param ip_address [String, nil] IP address for usage logging (Phase-02)
    # @param model [String, nil] AI model name for usage logging (Phase-02)
    # @param metadata [Hash] Additional metadata for usage logging (Phase-02)
    # @yield Block containing the AI API call
    # @return [Result] Result object with data or error
    def call(operation: 'ai_request', max_retries: MAX_RETRIES,
             service_name: nil, user: nil, ip_address: nil, model: nil, metadata: {}, &block)
      raise ArgumentError, 'Block is required' unless block_given?

      log_context = {
        service_name: service_name,
        operation: operation,
        user: user,
        ip_address: ip_address,
        model: model,
        metadata: metadata
      }

      # Check circuit breaker first
      if circuit_open?
        Rails.logger.warn "[AiRequestWrapper] Circuit OPEN for '#{operation}' - returning fallback"
        record_metric(:failure)
        result = Result.new(
          data: nil,
          error: 'Circuit breaker is open - AI service temporarily unavailable',
          success: false,
          fallback: true,
          attempts: 0,
          latency_ms: 0
        )
        log_ai_usage(result, log_context)
        return result
      end

      result = execute_with_retry(operation, max_retries, &block)
      log_ai_usage(result, log_context)
      result
    end

    # Get current metrics snapshot
    # @return [Hash] Current metrics
    def current_metrics
      @metrics_mutex.synchronize do
        avg_latency = if @metrics[:total_calls] > 0
                        (@metrics[:total_latency_ms].to_f / @metrics[:total_calls]).round(2)
                      else
                        0.0
                      end

        @metrics.merge(
          avg_latency_ms: avg_latency,
          circuit_state: @circuit_state,
          circuit_failure_count: @failure_count
        )
      end
    end

    # Reset metrics (primarily for testing)
    def reset_metrics!
      @metrics_mutex.synchronize do
        @metrics = {
          success_count: 0,
          failure_count: 0,
          retry_count: 0,
          total_latency_ms: 0,
          total_calls: 0
        }
      end
    end

    # Reset circuit breaker (primarily for testing)
    def reset_circuit!
      @circuit_mutex.synchronize do
        @circuit_state = :closed
        @failure_count = 0
        @last_failure_time = nil
      end
    end

    # Reset everything (for testing)
    def reset!
      reset_metrics!
      reset_circuit!
    end

    private

    # Execute the block with retry and exponential backoff
    def execute_with_retry(operation, max_retries, &block)
      attempts = 0
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      begin
        attempts += 1
        Rails.logger.info "[AiRequestWrapper] Attempt #{attempts}/#{max_retries} for '#{operation}'"

        result_data = yield

        # Success
        latency = calculate_latency_ms(start_time)
        record_success(latency)
        close_circuit!

        Rails.logger.info "[AiRequestWrapper] Success for '#{operation}' after #{attempts} attempt(s) (#{latency}ms)"

        Result.new(
          data: result_data,
          error: nil,
          success: true,
          fallback: false,
          attempts: attempts,
          latency_ms: latency
        )
      rescue *RETRYABLE_ERRORS, Faraday::Error => e
        if attempts < max_retries
          delay = BASE_DELAY**(attempts)
          Rails.logger.warn "[AiRequestWrapper] Retryable error on attempt #{attempts}/#{max_retries} " \
                            "for '#{operation}': #{e.class} - #{e.message}. " \
                            "Retrying in #{delay}s..."
          record_metric(:retry)
          sleep(delay)
          retry
        else
          # All retries exhausted
          latency = calculate_latency_ms(start_time)
          record_failure(latency)
          record_circuit_failure!

          Rails.logger.error "[AiRequestWrapper] All #{max_retries} attempts exhausted for '#{operation}': " \
                             "#{e.class} - #{e.message}"

          Result.new(
            data: nil,
            error: "#{e.class}: #{e.message}",
            success: false,
            fallback: circuit_open?,
            attempts: attempts,
            latency_ms: latency
          )
        end
      rescue StandardError => e
        handle_non_retryable_error(e, operation, attempts, start_time)
      end
    end

    # Handle errors that should not be retried (e.g., invalid API key, bad request)
    def handle_non_retryable_error(error, operation, attempts, start_time)
      latency = calculate_latency_ms(start_time)

      # OpenAI-specific error handling
      if openai_rate_limit_error?(error)
        record_failure(latency)
        record_circuit_failure!
        Rails.logger.error "[AiRequestWrapper] Rate limit error for '#{operation}': #{error.message}"
      elsif openai_auth_error?(error)
        Rails.logger.error "[AiRequestWrapper] Authentication error for '#{operation}': #{error.message} " \
                           '(not counting toward circuit breaker)'
        record_failure(latency)
      else
        record_failure(latency)
        record_circuit_failure!
        Rails.logger.error "[AiRequestWrapper] Non-retryable error for '#{operation}': " \
                           "#{error.class} - #{error.message}"
      end

      Result.new(
        data: nil,
        error: "#{error.class}: #{error.message}",
        success: false,
        fallback: circuit_open?,
        attempts: attempts,
        latency_ms: latency
      )
    end

    # === Circuit Breaker ===

    def circuit_open?
      @circuit_mutex.synchronize do
        case @circuit_state
        when :open
          if cooldown_elapsed?
            Rails.logger.info '[AiRequestWrapper] Circuit transitioning to HALF_OPEN (cooldown elapsed)'
            @circuit_state = :half_open
            false
          else
            true
          end
        when :half_open
          false # Allow one request through to test
        else
          false # :closed
        end
      end
    end

    def record_circuit_failure!
      @circuit_mutex.synchronize do
        @failure_count += 1
        @last_failure_time = Time.current

        if @failure_count >= CIRCUIT_FAILURE_THRESHOLD
          @circuit_state = :open
          Rails.logger.error "[AiRequestWrapper] Circuit OPENED after #{@failure_count} consecutive failures. " \
                             "Cooldown: #{CIRCUIT_COOLDOWN_SECONDS}s"
        end
      end
    end

    def close_circuit!
      @circuit_mutex.synchronize do
        if @circuit_state != :closed
          Rails.logger.info "[AiRequestWrapper] Circuit CLOSED (successful request after #{@circuit_state})"
        end
        @circuit_state = :closed
        @failure_count = 0
        @last_failure_time = nil
      end
    end

    def cooldown_elapsed?
      return true if @last_failure_time.nil?

      Time.current - @last_failure_time >= CIRCUIT_COOLDOWN_SECONDS
    end

    # === Metrics ===

    def record_success(latency_ms)
      record_metric(:success, latency_ms)
    end

    def record_failure(latency_ms)
      record_metric(:failure, latency_ms)
    end

    def record_metric(type, latency_ms = 0)
      @metrics_mutex.synchronize do
        case type
        when :success
          @metrics[:success_count] += 1
          @metrics[:total_calls] += 1
          @metrics[:total_latency_ms] += latency_ms
        when :failure
          @metrics[:failure_count] += 1
          @metrics[:total_calls] += 1
          @metrics[:total_latency_ms] += latency_ms
        when :retry
          @metrics[:retry_count] += 1
        end
      end
    end

    def calculate_latency_ms(start_time)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
    end

    # === OpenAI Error Classification ===

    def openai_rate_limit_error?(error)
      error.message.match?(/rate limit/i) ||
        (defined?(OpenAI::Error) && error.is_a?(OpenAI::Error) && error.message.match?(/429|rate/i))
    end

    def openai_auth_error?(error)
      error.message.match?(/invalid.*api.*key|unauthorized|authentication/i) ||
        (defined?(OpenAI::Error) && error.is_a?(OpenAI::Error) && error.message.match?(/401|auth/i))
    end

    # === AI Usage Logging (Phase-02) ===

    # Log AI API call to ai_usage_logs table
    # @param result [Result] The result of the API call
    # @param context [Hash] Logging context (service_name, operation, user, etc.)
    def log_ai_usage(result, context)
      return unless context[:service_name].present?

      # Extract token usage from result data if available
      tokens = extract_token_usage(result.data)

      AiUsageLog.create!(
        user: context[:user],
        service_name: context[:service_name],
        operation: context[:operation] || 'unknown',
        tokens_input: tokens[:input],
        tokens_output: tokens[:output],
        model: context[:model] || detect_model_from_data(result.data),
        latency_ms: result.latency_ms.to_i,
        attempts: result.attempts || 1,
        success: result.success?,
        from_cache: false,
        error_message: result.error&.truncate(500),
        ip_address: context[:ip_address],
        metadata: context[:metadata] || {}
      )

      # Check daily budget after logging
      check_daily_budget_alert
    rescue StandardError => e
      # Never let logging failure break the main flow
      Rails.logger.warn "[AiRequestWrapper] Failed to log AI usage: #{e.message}"
    end

    # Log a cache hit (no actual API call made)
    # Called externally when a cached result is used
    def log_cache_hit(service_name:, operation:, user: nil, ip_address: nil)
      AiUsageLog.create!(
        user: user,
        service_name: service_name,
        operation: operation,
        tokens_input: 0,
        tokens_output: 0,
        latency_ms: 0,
        attempts: 0,
        success: true,
        from_cache: true,
        ip_address: ip_address
      )
    rescue StandardError => e
      Rails.logger.warn "[AiRequestWrapper] Failed to log cache hit: #{e.message}"
    end

    # Extract token usage from OpenAI response
    def extract_token_usage(data)
      return { input: 0, output: 0 } unless data.is_a?(Hash)

      usage = data['usage'] || data[:usage]
      return { input: 0, output: 0 } unless usage

      {
        input: usage['prompt_tokens'] || usage[:prompt_tokens] || 0,
        output: usage['completion_tokens'] || usage[:completion_tokens] || 0
      }
    end

    # Try to detect model from response data
    def detect_model_from_data(data)
      return nil unless data.is_a?(Hash)

      data['model'] || data[:model]
    end

    # Check if daily budget exceeded and send alert
    def check_daily_budget_alert
      return unless AiUsageLog.daily_budget_exceeded?

      # Only alert once per day using Redis flag
      alert_key = "ai_budget_alert:#{Date.current}"
      redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'))

      return if redis.get(alert_key).present?

      redis.setex(alert_key, 86400, '1') # Set flag for 24 hours

      Rails.logger.error "[AiRequestWrapper] ALERT: Daily AI budget exceeded! " \
                         "Spent: $#{AiUsageLog.todays_cost.round(4)}, " \
                         "Budget: $#{ENV.fetch('AI_DAILY_BUDGET_USD', '10.0')}"

      # Enqueue alert job if Sidekiq is available
      AiBudgetAlertJob.perform_later if defined?(AiBudgetAlertJob)
    rescue Redis::BaseError => e
      Rails.logger.warn "[AiRequestWrapper] Redis error in budget check: #{e.message}"
    end
  end
end
