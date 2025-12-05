# frozen_string_literal: true

module TireChat
  # Conversation manager for session and context management
  # Handles conversation history, filters, and user preferences
  class ConversationManager
    MAX_HISTORY_LENGTH = 20
    SESSION_TTL = 30.minutes

    # Conversation data structure
    class Conversation
      attr_accessor :history, :filters, :preferences, :locale, :created_at, :updated_at

      def initialize(locale: 'ru', filters: {}, preferences: {})
        @history = []
        @filters = initialize_filters(filters)
        @preferences = preferences || {}
        @locale = locale || 'ru'
        @created_at = Time.current
        @updated_at = Time.current
      end

      def to_h
        {
          history: @history,
          filters: @filters,
          preferences: @preferences,
          locale: @locale,
          created_at: @created_at,
          updated_at: @updated_at
        }
      end

      private

      def initialize_filters(filters)
        {
          size: nil,
          season: nil,
          budget_min: nil,
          budget_max: nil,
          brand_preferences: nil,
          priority_type: nil
        }.merge(filters || {})
      end
    end

    attr_reader :conversation

    def initialize(conversation_history: [], current_filters: {}, user_preferences: {}, locale: 'ru')
      @conversation = Conversation.new(
        locale: locale,
        filters: current_filters,
        preferences: user_preferences
      )
      @conversation.history = conversation_history || []
    end

    # Get or create conversation (for Redis-based storage in future)
    # @param session_id [String] Session identifier
    # @return [Conversation] Conversation object
    def self.get_or_create(session_id, locale: 'ru')
      # Future: Load from Redis/cache
      # For now, create new conversation
      new(locale: locale)
    end

    # Add message to conversation history
    # @param role [Symbol] Message role (:user or :assistant)
    # @param message [String] Message content
    def add_message(role, message)
      @conversation.history << {
        role: role,
        message: message,
        timestamp: Time.current
      }

      trim_history
      touch
    end

    # Get conversation history
    # @return [Array<Hash>] Message history
    def history
      @conversation.history
    end

    # Get current filters
    # @return [Hash] Current search filters
    def filters
      @conversation.filters
    end

    # Get user preferences
    # @return [Hash] User preferences
    def preferences
      @conversation.preferences
    end

    # Get locale
    # @return [String] Current locale
    def locale
      @conversation.locale
    end

    # Update filters from parameters
    # @param parameters [Hash] Parameters to update
    def update_filters(parameters)
      if parameters[:size].present?
        @conversation.filters[:size] = parse_size(parameters[:size])
      end

      if parameters[:season].present?
        @conversation.filters[:season] = normalize_season(parameters[:season])
        Rails.logger.info "🔄 Нормализация сезона: '#{parameters[:season]}' → '#{@conversation.filters[:season]}'"
      end

      @conversation.filters[:brands] = parameters[:brands].map(&:downcase) if parameters[:brands].present?

      touch
      log_filters
    end

    # Update user preferences
    # @param preferences [Hash] Preferences to update
    def update_preferences(preferences)
      if preferences[:priority_type].present?
        @conversation.preferences[:priority_type] = normalize_priority(preferences[:priority_type])
      end

      if preferences[:price_segment].present?
        @conversation.preferences[:price_segment] = preferences[:price_segment]
        Rails.logger.info "💰 Установлен ценовой сегмент: #{@conversation.preferences[:price_segment]}"
      end

      if preferences[:car_model].present?
        @conversation.preferences[:car_model] = preferences[:car_model]
      end

      touch
      log_preferences
    end

    # Check if ready for recommendations
    # @return [Boolean] True if all required filters are set
    def ready_for_recommendations?
      @conversation.filters[:size].present? && @conversation.filters[:season].present?
    end

    # Clear conversation and reset filters
    def clear
      @conversation = Conversation.new(locale: @conversation.locale)
      Rails.logger.info "🔄 Conversation cleared"
    end

    # Reset filters only (keep history)
    def reset_filters
      @conversation.filters = {
        size: nil,
        season: nil,
        budget_min: nil,
        budget_max: nil,
        brand_preferences: nil,
        priority_type: nil
      }
      @conversation.preferences = {}
      Rails.logger.info "🔄 Filters and preferences reset"
    end

    # Get next step based on current state
    # @return [String] Next step identifier
    def determine_next_step
      if @conversation.filters[:size].blank?
        'size_request'
      elsif @conversation.filters[:season].blank?
        'season_request'
      else
        'recommendation_request'
      end
    end

    # Get next question text based on missing parameters
    # @return [String] Question about missing parameters
    def get_next_question
      missing_params = []

      if @conversation.filters[:size].blank?
        missing_params << missing_size_message
        Rails.logger.info "📏 Отсутствует размер шин"
      end

      if @conversation.filters[:season].blank?
        missing_params << missing_season_message
        Rails.logger.info "🌤️ Отсутствует сезон шин"
      end

      if missing_params.any?
        result = "#{need_more_info_message}\n#{missing_params.join("\n")}"
        Rails.logger.info "❓ Запрашиваем недостающие параметры: #{missing_params.length}"
        result
      else
        Rails.logger.info "✅ Все параметры готовы для рекомендаций"
        ready_to_recommend_message
      end
    end

    # Format conversation history for AI prompt
    # @param limit [Integer] Maximum messages to include
    # @return [String] Formatted history
    def format_for_prompt(limit: 10)
      @conversation.history.last(limit).map do |entry|
        "#{entry[:role] == :user ? 'Пользователь' : 'Ассистент'}: #{entry[:message]}"
      end.join("\n")
    end

    # Save conversation (for Redis-based storage in future)
    # @param session_id [String] Session identifier
    def save(session_id)
      # Future: Save to Redis with TTL
      # Rails.cache.write(cache_key(session_id), @conversation.to_h, expires_in: SESSION_TTL)
    end

    private

    def trim_history
      @conversation.history = @conversation.history.last(MAX_HISTORY_LENGTH)
    end

    def touch
      @conversation.updated_at = Time.current
    end

    def parse_size(size_text)
      return size_text if size_text.is_a?(Hash)

      matches = size_text.to_s.match(/(\d{2,3})[\/\s]*(\d{2})[\/\s]*[rR]?(\d{1,2})/)

      if matches
        {
          width: matches[1].to_i,
          height: matches[2].to_i,
          diameter: matches[3].to_i,
          full_size: "#{matches[1]}/#{matches[2]}R#{matches[3]}"
        }
      end
    end

    def normalize_season(season_text)
      case season_text.to_s.downcase
      when /летн|літн|лето|літо|summer/
        'summer'
      when /зимн|зимов|зима|winter/
        'winter'
      when /всесезон|всесезон|all.season/
        'all_season'
      else
        season_text
      end
    end

    def normalize_priority(priority_text)
      priority_lower = priority_text.to_s.downcase

      case priority_lower
      when /цен.*качеств|соотношен|бюджет|выгод/
        'price_quality'
      when /престиж|статус|бренд|имидж|топ/
        'prestige'
      when /функц|техн|характер|производ|надеж/
        'functionality'
      else
        'balanced'
      end
    end

    def log_filters
      Rails.logger.info "🔧 Обновленные фильтры: #{@conversation.filters}"
    end

    def log_preferences
      Rails.logger.info "🎯 Обновленные предпочтения: #{@conversation.preferences}"
    end

    def cache_key(session_id)
      "tire_chat:conversation:#{session_id}"
    end

    # Localized messages
    def need_more_info_message
      @conversation.locale == 'uk' ? 'Для підбору оптимальних шин мені потрібно знати:' : 'Для подбора оптимальных шин мне нужно знать:'
    end

    def missing_size_message
      @conversation.locale == 'uk' ? '📏 **Розмір шин** - наприклад: 205/55R16, 225/60R17' : '📏 **Размер шин** - например: 205/55R16, 225/60R17'
    end

    def missing_season_message
      @conversation.locale == 'uk' ? '🌤️ **Сезон** - зимові, літні чи всесезонні шини' : '🌤️ **Сезон** - зимние, летние или всесезонные шины'
    end

    def ready_to_recommend_message
      @conversation.locale == 'uk' ? 'Відмінно! У мене є всі необхідні дані. Шукаю найкращі варіанти для вас...' : 'Отлично! У меня есть все необходимые данные. Ищу лучшие варианты для вас...'
    end
  end
end
