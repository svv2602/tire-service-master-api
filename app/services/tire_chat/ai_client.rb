# frozen_string_literal: true

module TireChat
  # AI Client for interaction with OpenAI API
  # Handles chat completion requests, retries, and error handling
  class AIClient
    class APIError < StandardError; end
    class RateLimitError < APIError; end
    class TimeoutError < APIError; end

    # Configuration
    DEFAULT_MODEL = 'gpt-4o-mini'
    DEFAULT_TEMPERATURE = 0.7
    DEFAULT_MAX_TOKENS = 1000
    MAX_RETRIES = 3
    RETRY_DELAY = 1 # seconds, will be multiplied exponentially

    attr_reader :openai_service

    def initialize(openai_service: nil)
      @openai_service = openai_service || OpenaiService.new
    end

    # Check if OpenAI service is available
    def available?
      OpenaiService.available?
    end

    # Standard chat completion request
    # @param prompt [String] The prompt to send
    # @param options [Hash] Additional options (model, temperature, max_tokens)
    # @return [String, nil] The response content or nil on failure
    def chat(prompt, options = {})
      return nil unless available?

      with_retry do
        response = @openai_service.send(:chat_completion, prompt, options)
        extract_content(response)
      end
    rescue => e
      handle_error(e)
      nil
    end

    # Generate tire chat response using OpenAI
    # @param message [String] User message
    # @param filters [Hash] Current search filters
    # @param locale [String] Language locale (ru/uk)
    # @return [String, nil] Generated response or nil
    def generate_tire_response(message, filters = {}, locale = 'ru')
      return nil unless available?

      with_retry do
        @openai_service.generate_tire_chat_response(message, filters, locale)
      end
    rescue => e
      handle_error(e)
      nil
    end

    # Analyze user intent using AI
    # @param prompt [String] Analysis prompt
    # @return [Hash] Parsed intent response
    def analyze_intent(prompt)
      response_content = chat(prompt)
      parse_json_response(response_content) || default_intent
    end

    private

    # Retry logic with exponential backoff
    def with_retry(max_retries: MAX_RETRIES)
      retries = 0
      begin
        yield
      rescue RateLimitError, TimeoutError => e
        retries += 1
        if retries <= max_retries
          sleep_time = RETRY_DELAY * (2 ** (retries - 1))
          Rails.logger.warn "⚠️ TireChat::AIClient retry #{retries}/#{max_retries} after #{sleep_time}s: #{e.message}"
          sleep(sleep_time)
          retry
        else
          raise
        end
      end
    end

    # Extract content from OpenAI response
    def extract_content(response)
      response&.dig('choices', 0, 'message', 'content')
    end

    # Parse JSON response, handling markdown code blocks
    def parse_json_response(content)
      return nil if content.blank?

      json_content = content.strip

      # Remove markdown code blocks if present
      if json_content.start_with?('```json') && json_content.end_with?('```')
        json_content = json_content.gsub(/\A```json\n?/, '').gsub(/\n?```\z/, '')
      elsif json_content.start_with?('```') && json_content.end_with?('```')
        json_content = json_content.gsub(/\A```\n?/, '').gsub(/\n?```\z/, '')
      end

      JSON.parse(json_content).with_indifferent_access
    rescue JSON::ParserError => e
      Rails.logger.error "❌ TireChat::AIClient JSON parse error: #{e.message}"
      nil
    end

    # Default intent when parsing fails
    def default_intent
      { type: 'general_question', parameters: {}, confidence: 0.1 }
    end

    # Handle and classify errors
    def handle_error(error)
      case error.message
      when /rate limit/i
        Rails.logger.error "❌ TireChat::AIClient rate limit exceeded"
        raise RateLimitError, error.message
      when /timeout/i
        Rails.logger.error "❌ TireChat::AIClient request timeout"
        raise TimeoutError, error.message
      else
        Rails.logger.error "❌ TireChat::AIClient error: #{error.message}"
      end
    end
  end
end
