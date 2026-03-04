# frozen_string_literal: true

module TireChat
  # AI Client for interaction with OpenAI API
  # Uses AiRequestWrapper for retry, circuit breaker, and error handling
  class AIClient
    class APIError < StandardError; end
    class RateLimitError < APIError; end
    class TimeoutError < APIError; end

    # Configuration
    DEFAULT_MODEL = 'gpt-4.1-mini'
    DEFAULT_TEMPERATURE = 0.7
    DEFAULT_MAX_TOKENS = 1000

    # Fallback message when AI is unavailable
    FALLBACK_MESSAGE_RU = 'Извините, сервис AI-консультанта временно недоступен. Попробуйте позже или воспользуйтесь каталогом шин.'
    FALLBACK_MESSAGE_UK = 'Вибачте, сервiс AI-консультанта тимчасово недоступний. Спробуйте пiзнiше або скористайтеся каталогом шин.'

    attr_reader :openai_service

    def initialize(openai_service: nil)
      @openai_service = openai_service || OpenaiService.new
    end

    # Check if OpenAI service is available
    def available?
      OpenaiService.available?
    end

    # Standard chat completion request with AiRequestWrapper resilience
    # @param prompt [String] The prompt to send
    # @param options [Hash] Additional options (model, temperature, max_tokens)
    # @return [String, nil] The response content or nil on failure
    def chat(prompt, options = {})
      return nil unless available?

      result = AiRequestWrapper.call(operation: 'tire_chat_completion') do
        response = @openai_service.send(:chat_completion, prompt, options)
        extract_content(response)
      end

      if result.success?
        result.data
      else
        Rails.logger.error "TireChat::AIClient chat failed: #{result.error}"
        nil
      end
    end

    # Generate tire chat response using OpenAI with fallback
    # @param message [String] User message
    # @param filters [Hash] Current search filters
    # @param locale [String] Language locale (ru/uk)
    # @return [String, nil] Generated response or fallback message
    def generate_tire_response(message, filters = {}, locale = 'ru')
      return fallback_message(locale) unless available?

      result = AiRequestWrapper.call(operation: 'tire_chat_response') do
        @openai_service.generate_tire_chat_response(message, filters, locale)
      end

      if result.success? && result.data.present?
        result.data
      elsif result.fallback?
        Rails.logger.warn 'TireChat::AIClient: circuit open, returning fallback message'
        fallback_message(locale)
      else
        nil
      end
    end

    # Analyze user intent using AI
    # @param prompt [String] Analysis prompt
    # @return [Hash] Parsed intent response
    def analyze_intent(prompt)
      response_content = chat(prompt)
      parse_json_response(response_content) || default_intent
    end

    # Get fallback message for unavailable AI
    # @param locale [String] Language locale
    # @return [String] Fallback message
    def fallback_message(locale = 'ru')
      locale == 'uk' ? FALLBACK_MESSAGE_UK : FALLBACK_MESSAGE_RU
    end

    private

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
      Rails.logger.error "TireChat::AIClient JSON parse error: #{e.message}"
      nil
    end

    # Default intent when parsing fails
    def default_intent
      { type: 'general_question', parameters: {}, confidence: 0.1 }
    end
  end
end
