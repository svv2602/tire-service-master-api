# frozen_string_literal: true

module TireChat
  # Conversation manager for session and context management
  # Handles conversation history, filters, and user preferences
  # Now uses database persistence via Conversation model
  class ConversationManager
    MAX_HISTORY_LENGTH = 20
    SESSION_TTL = 30.minutes

    attr_reader :conversation, :filters, :preferences, :locale

    def initialize(session_id:, user: nil, locale: 'ru', current_filters: {}, user_preferences: {})
      @locale = locale || 'ru'
      @filters = initialize_filters(current_filters)
      @preferences = user_preferences || {}

      # Find or create database conversation
      @conversation = find_or_create_conversation(session_id, user)
    end

    # Legacy constructor for backward compatibility
    def self.from_history(conversation_history: [], current_filters: {}, user_preferences: {}, locale: 'ru')
      # Create a temporary session for legacy API
      session_id = SecureRandom.uuid
      manager = new(session_id: session_id, locale: locale, current_filters: current_filters, user_preferences: user_preferences)

      # Import legacy history if provided
      conversation_history&.each do |entry|
        role = entry[:role].to_s == 'user' ? 'user' : 'assistant'
        manager.conversation.messages.create!(role: role, content: entry[:message] || entry[:content])
      end

      manager
    end

    # Get or create conversation (class method for convenience)
    def self.get_or_create(session_id, user: nil, locale: 'ru')
      new(session_id: session_id, user: user, locale: locale)
    end

    # Find or create conversation in database
    def find_or_create_conversation(session_id, user = nil)
      ::Conversation.find_or_create_for(session_id: session_id, user: user)
    end

    # Add message to conversation history
    def add_message(role, message, metadata: {})
      role_str = role.to_s == 'user' ? 'user' : 'assistant'

      @conversation.messages.create!(
        role: role_str,
        content: message,
        metadata: metadata
      )
      @conversation.touch
    end

    # Add user message (convenience method)
    def add_user_message(content)
      @conversation.add_user_message(content)
    end

    # Add assistant message with optional metadata
    def add_assistant_message(content, metadata: {})
      @conversation.add_assistant_message(content, metadata: metadata)
    end

    # Get conversation history
    def history
      @conversation.messages.chronological.map do |msg|
        {
          role: msg.role.to_sym,
          message: msg.content,
          timestamp: msg.created_at
        }
      end
    end

    # Get context for AI (formatted for OpenAI)
    def context_for_ai(limit: MAX_HISTORY_LENGTH)
      @conversation.context_for_ai(limit: limit)
    end

    # Update filters from parameters
    def update_filters(parameters)
      if parameters[:size].present?
        @filters[:size] = parse_size(parameters[:size])
      end

      if parameters[:season].present?
        @filters[:season] = normalize_season(parameters[:season])
        Rails.logger.info "🔄 Нормализация сезона: '#{parameters[:season]}' → '#{@filters[:season]}'"
      end

      @filters[:brands] = parameters[:brands].map(&:downcase) if parameters[:brands].present?

      # Save filters to conversation metadata
      save_filters_to_metadata

      log_filters
    end

    # Update user preferences
    def update_preferences(preferences)
      if preferences[:priority_type].present?
        @preferences[:priority_type] = normalize_priority(preferences[:priority_type])
      end

      if preferences[:price_segment].present?
        @preferences[:price_segment] = preferences[:price_segment]
        Rails.logger.info "💰 Установлен ценовой сегмент: #{@preferences[:price_segment]}"
      end

      if preferences[:car_model].present?
        @preferences[:car_model] = preferences[:car_model]
      end

      # Save preferences to conversation metadata
      save_preferences_to_metadata

      log_preferences
    end

    # Check if ready for recommendations
    def ready_for_recommendations?
      @filters[:size].present? && @filters[:season].present?
    end

    # Clear conversation and reset filters
    def clear
      @conversation.close!
      @conversation = ::Conversation.create!(
        session_id: SecureRandom.uuid,
        user: @conversation.user,
        status: 'active'
      )
      @filters = initialize_filters({})
      @preferences = {}
      Rails.logger.info "🔄 Conversation cleared"
    end

    # Reset filters only (keep history)
    def reset_filters
      @filters = initialize_filters({})
      @preferences = {}
      save_filters_to_metadata
      save_preferences_to_metadata
      Rails.logger.info "🔄 Filters and preferences reset"
    end

    # Get next step based on current state
    def determine_next_step
      if @filters[:size].blank?
        'size_request'
      elsif @filters[:season].blank?
        'season_request'
      else
        'recommendation_request'
      end
    end

    # Get next question text based on missing parameters
    def get_next_question
      missing_params = []

      if @filters[:size].blank?
        missing_params << missing_size_message
        Rails.logger.info "📏 Отсутствует размер шин"
      end

      if @filters[:season].blank?
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
    def format_for_prompt(limit: 10)
      @conversation.messages.chronological.last(limit).map do |msg|
        "#{msg.role == 'user' ? 'Пользователь' : 'Ассистент'}: #{msg.content}"
      end.join("\n")
    end

    # Get conversation ID
    def conversation_id
      @conversation.id
    end

    # Get session ID
    def session_id
      @conversation.session_id
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

    def save_filters_to_metadata
      @conversation.update!(
        metadata: (@conversation.metadata || {}).merge('filters' => @filters)
      )
    end

    def save_preferences_to_metadata
      @conversation.update!(
        metadata: (@conversation.metadata || {}).merge('preferences' => @preferences)
      )
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
      Rails.logger.info "🔧 Обновленные фильтры: #{@filters}"
    end

    def log_preferences
      Rails.logger.info "🎯 Обновленные предпочтения: #{@preferences}"
    end

    # Localized messages
    def need_more_info_message
      @locale == 'uk' ? 'Для підбору оптимальних шин мені потрібно знати:' : 'Для подбора оптимальных шин мне нужно знать:'
    end

    def missing_size_message
      @locale == 'uk' ? '📏 **Розмір шин** - наприклад: 205/55R16, 225/60R17' : '📏 **Размер шин** - например: 205/55R16, 225/60R17'
    end

    def missing_season_message
      @locale == 'uk' ? '🌤️ **Сезон** - зимові, літні чи всесезонні шини' : '🌤️ **Сезон** - зимние, летние или всесезонные шины'
    end

    def ready_to_recommend_message
      @locale == 'uk' ? 'Відмінно! У мене є всі необхідні дані. Шукаю найкращі варіанти для вас...' : 'Отлично! У меня есть все необходимые данные. Ищу лучшие варианты для вас...'
    end
  end
end
