# frozen_string_literal: true

module TireChat
  # Main orchestrator service for tire chat functionality
  # Composes all TireChat modules and handles intent routing
  class Service
    include ActionView::Helpers::TextHelper

    attr_reader :conversation_manager, :message_processor, :search_adapter, :response_formatter, :ai_client

    def initialize(conversation_history: [], current_filters: {}, user_preferences: {}, locale: 'ru')
      @ai_client = AIClient.new
      @message_processor = MessageProcessor.new(ai_client: @ai_client)
      @conversation_manager = ConversationManager.new(
        conversation_history: conversation_history,
        current_filters: current_filters,
        user_preferences: user_preferences,
        locale: locale
      )
      @response_formatter = ResponseFormatter.new(locale: locale)
      @search_adapter = SearchAdapter.new(
        filters: @conversation_manager.filters,
        user_preferences: @conversation_manager.preferences
      )
    end

    # Main method to process user message
    # @param user_message [String] User's message
    # @param available_products [ActiveRecord::Relation, nil] Optional products scope
    # @param is_quick_question [Boolean] True if this is a standalone quick question
    # @return [Hash] Response with message, filters, recommendations, etc.
    def process_message(user_message, available_products = nil, is_quick_question: false)
      Rails.logger.info "🤖 Обработка сообщения: #{user_message} (быстрый вопрос: #{is_quick_question})"

      reset_for_quick_question if is_quick_question

      @conversation_manager.add_message(:user, user_message)

      intent = @message_processor.analyze(
        user_message,
        conversation_history: @conversation_manager.history,
        current_filters: @conversation_manager.filters
      )

      Rails.logger.info "🎯 Определено намерение: #{intent[:type]}"

      response = handle_intent(intent, available_products)
      @conversation_manager.add_message(:assistant, response[:message])

      response
    rescue StandardError => e
      Rails.logger.error "❌ Ошибка в TireChat::Service: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      fallback_response
    end

    # Get current conversation history
    # @return [Array<Hash>] Conversation history
    def conversation_history
      @conversation_manager.history
    end

    # Get current filters
    # @return [Hash] Current search filters
    def current_filters
      @conversation_manager.filters
    end

    # Get user preferences
    # @return [Hash] User preferences
    def user_preferences
      @conversation_manager.preferences
    end

    # Get locale
    # @return [String] Current locale
    def locale
      @conversation_manager.locale
    end

    # Clear conversation
    def clear_conversation
      @conversation_manager.clear
    end

    private

    def reset_for_quick_question
      Rails.logger.info "🔄 Сброс параметров для быстрого вопроса"
      @conversation_manager.reset_filters
    end

    # Route intent to appropriate handler
    def handle_intent(intent, available_products)
      case intent[:type]
      when 'complex_request'
        handle_complex_request(intent, available_products)
      when 'size_request'
        handle_size_request(intent[:parameters])
      when 'priority_request'
        handle_priority_request(intent[:parameters])
      when 'price_segment_request'
        handle_price_segment_request(intent[:parameters], available_products)
      when 'recommendation_request'
        handle_recommendation_request(intent[:parameters], available_products)
      when 'brand_preference'
        handle_brand_preference(intent[:parameters])
      when 'season_preference'
        handle_season_preference(intent[:parameters], available_products)
      when 'budget_constraint'
        handle_budget_constraint(intent[:parameters])
      when 'technical_question'
        handle_technical_question(intent[:parameters], available_products)
      when 'new_search_request'
        handle_new_search_request(intent[:parameters])
      when 'continue_discussion'
        handle_continue_discussion(intent[:parameters])
      when 'car_model_request'
        handle_car_model_request(intent[:parameters])
      when 'size_guide_request'
        handle_size_guide_request(intent[:parameters])
      when 'brand_comparison_request'
        handle_brand_comparison_request(intent[:parameters])
      when 'openai_chat_request'
        handle_openai_chat_request(intent[:original_message] || '', intent[:parameters], available_products)
      else
        handle_general_question(intent[:parameters], available_products)
      end
    end

    # Handle complex request with multiple intents
    def handle_complex_request(intent, available_products)
      parameters = intent[:parameters]
      intent_types = intent[:intent_types] || []

      Rails.logger.info "🎯 Обработка комплексного запроса: #{intent_types.join(', ')}"

      return handle_brand_comparison_request(parameters) if intent_types.include?('brand_comparison_request')

      if intent_types.include?('car_model_request') && !parameters[:size].present?
        return handle_car_model_request(parameters)
      end

      update_context_from_parameters(parameters)

      if should_show_recommendations?(intent_types)
        show_recommendations(intent_types, parameters, available_products)
      else
        confirm_parameters(parameters)
      end
    end

    def should_show_recommendations?(intent_types)
      intent_types.include?('recommendation_request') ||
        intent_types.include?('price_segment_request') ||
        @conversation_manager.ready_for_recommendations?
    end

    def show_recommendations(intent_types, parameters, available_products)
      Rails.logger.info "🎯 Все данные готовы, показываем рекомендации"

      confirmations = build_confirmations(parameters)

      if intent_types.include?('price_segment_request') || @conversation_manager.preferences[:price_segment].present?
        show_price_segment_recommendations(confirmations, parameters, available_products)
      else
        show_standard_recommendations(confirmations, available_products)
      end
    end

    def show_price_segment_recommendations(confirmations, parameters, available_products)
      price_segment = parameters[:price_segment] || @conversation_manager.preferences[:price_segment]
      recommendations = get_price_segment_recommendations(available_products, price_segment)

      if recommendations.any?
        catalog_button_data = get_catalog_button_data
        confirmation_msg = format_confirmation_message(confirmations)
        recommendations_text = @response_formatter.format_price_segment_recommendations(recommendations, price_segment)

        {
          message: "#{confirmation_msg}#{recommendations_text}",
          filters_updated: @conversation_manager.filters,
          preferences_updated: @conversation_manager.preferences,
          recommendations: recommendations,
          catalog_button: catalog_button_data,
          action: 'show_price_segment_recommendations'
        }
      else
        no_results_response(confirmations)
      end
    end

    def show_standard_recommendations(confirmations, available_products)
      recommendations = get_tire_recommendations(available_products)

      if recommendations.any?
        catalog_button_data = get_catalog_button_data
        confirmation_msg = format_confirmation_message(confirmations)
        recommendations_text = @response_formatter.format_recommendations(
          recommendations,
          priority_type: @conversation_manager.preferences[:priority_type]
        )

        {
          message: "#{confirmation_msg}#{recommendations_text}",
          filters_updated: @conversation_manager.filters,
          preferences_updated: @conversation_manager.preferences,
          recommendations: recommendations,
          catalog_button: catalog_button_data,
          action: 'show_recommendations_with_options'
        }
      else
        no_results_response(confirmations)
      end
    end

    def build_confirmations(parameters)
      confirmations = []
      locale = @conversation_manager.locale

      if parameters[:size].present?
        size_text = locale == 'uk' ? 'розмір' : 'размер'
        confirmations << "#{size_text} #{parameters[:size]}"
      end

      if parameters[:season].present?
        season_name = @response_formatter.season_display_name(parameters[:season]).downcase
        tires_text = locale == 'uk' ? 'шини' : 'шины'
        confirmations << "#{season_name} #{tires_text}"
      end

      if parameters[:priority].present?
        priority_text = locale == 'uk' ? 'пріоритет' : 'приоритет'
        confirmations << "#{priority_text}: #{parameters[:priority]}"
      end

      confirmations
    end

    def format_confirmation_message(confirmations)
      return "" unless confirmations.any?

      accepted_text = @conversation_manager.locale == 'uk' ? 'Прийнято' : 'Принято'
      "✅ #{accepted_text}: #{confirmations.join(', ')}.\n\n"
    end

    def no_results_response(confirmations)
      confirmation_msg = confirmations.any? ? "✅ Принято: #{confirmations.join(', ')}.\n\n" : ""
      {
        message: "#{confirmation_msg}😔 #{t('no_results')}",
        filters_updated: @conversation_manager.filters,
        preferences_updated: @conversation_manager.preferences,
        action: 'no_results'
      }
    end

    def confirm_parameters(parameters)
      confirmations = []
      confirmations << "размер #{parameters[:size]}" if parameters[:size].present?
      confirmations << "#{parameters[:season]} шины" if parameters[:season].present?
      confirmations << "приоритет: #{parameters[:priority]}" if parameters[:priority].present?

      {
        message: "✅ Принято: #{confirmations.join(', ')}. #{@conversation_manager.get_next_question}",
        filters_updated: @conversation_manager.filters,
        preferences_updated: @conversation_manager.preferences,
        next_step: @conversation_manager.determine_next_step
      }
    end

    def update_context_from_parameters(parameters)
      @conversation_manager.update_filters(parameters)
      @conversation_manager.update_preferences(
        priority_type: parameters[:priority],
        price_segment: parameters[:price_segment]
      )
      refresh_search_adapter
    end

    def refresh_search_adapter
      @search_adapter = SearchAdapter.new(
        filters: @conversation_manager.filters,
        user_preferences: @conversation_manager.preferences
      )
    end

    # Handle size request
    def handle_size_request(parameters)
      size = parameters[:size]
      if size.present?
        @conversation_manager.update_filters(size: size)
        refresh_search_adapter

        if @conversation_manager.ready_for_recommendations?
          recommendations = get_tire_recommendations
          return show_size_recommendations(size, recommendations) if recommendations.any?

          return no_results_for_size(size)
        end

        {
          message: "✅ #{t('size_accepted', size: size)} #{@conversation_manager.get_next_question}",
          filters_updated: @conversation_manager.filters,
          next_step: @conversation_manager.determine_next_step
        }
      else
        {
          message: "🤔 #{t('size_not_recognized')}",
          next_step: 'size_request'
        }
      end
    end

    def show_size_recommendations(size, recommendations)
      catalog_button_data = get_catalog_button_data
      recommendations_text = @response_formatter.format_recommendations(
        recommendations,
        priority_type: @conversation_manager.preferences[:priority_type]
      )

      {
        message: "✅ #{t('size_accepted', size: size)}\n\n#{recommendations_text}",
        filters_updated: @conversation_manager.filters,
        recommendations: recommendations,
        catalog_button: catalog_button_data,
        action: 'show_recommendations'
      }
    end

    def no_results_for_size(size)
      size_info = @conversation_manager.filters[:size][:full_size]
      season_info = @conversation_manager.filters[:season]

      {
        message: "✅ #{t('size_accepted', size: size)}\n\n#{t('no_results_suggest_changes', size: size_info, season: season_info)}",
        filters_updated: @conversation_manager.filters,
        action: 'no_results',
        next_step: 'parameter_adjustment'
      }
    end

    # Handle priority request
    def handle_priority_request(parameters)
      priority = parameters[:priority]
      if priority.present?
        @conversation_manager.update_preferences(priority_type: priority)
        refresh_search_adapter
        next_step = @conversation_manager.ready_for_recommendations? ? 'recommendation_request' : @conversation_manager.determine_next_step

        {
          message: "👍 #{t('priority_accepted', priority_description: get_priority_description(priority))} #{@conversation_manager.get_next_question}",
          preferences_updated: @conversation_manager.preferences,
          next_step: next_step
        }
      else
        {
          message: t('priority_options'),
          next_step: 'priority_request'
        }
      end
    end

    # Handle new search request
    def handle_new_search_request(_parameters)
      Rails.logger.info "🆕 Обработка запроса нового поиска"
      @conversation_manager.reset_filters
      refresh_search_adapter

      {
        message: "🔄 #{t('new_search_started')}\n\n#{t('need_car_or_size_info')}",
        filters_updated: @conversation_manager.filters,
        preferences_updated: @conversation_manager.preferences,
        action: 'new_search_started',
        next_step: 'specify_car_or_size'
      }
    end

    # Handle price segment request
    def handle_price_segment_request(parameters, available_products)
      price_segment = parameters[:price_segment]
      @conversation_manager.update_preferences(price_segment: price_segment)
      refresh_search_adapter

      if @conversation_manager.filters[:size].blank?
        segment_name = @response_formatter.price_segment_name(price_segment)
        return {
          message: "👍 #{t('price_segment_request_size', segment_name: segment_name)}",
          preferences_updated: @conversation_manager.preferences,
          next_step: 'size_request'
        }
      end

      if @conversation_manager.filters[:season].blank?
        segment_name = @response_formatter.price_segment_name(price_segment)
        size_display = @conversation_manager.filters[:size][:full_size]
        return {
          message: "👍 #{t('price_segment_request_season', segment_name: segment_name, size: size_display)}",
          preferences_updated: @conversation_manager.preferences,
          next_step: 'season_request'
        }
      end

      recommendations = get_price_segment_recommendations(available_products, price_segment)
      show_price_segment_results(recommendations, price_segment)
    end

    def show_price_segment_results(recommendations, price_segment)
      if recommendations.any?
        catalog_button_data = get_catalog_button_data
        segment_name = @response_formatter.price_segment_name(price_segment)
        tires_text = @conversation_manager.locale == 'uk' ? 'шини розміру' : 'шины размера'
        size_display = @conversation_manager.filters[:size][:full_size]

        {
          message: "👍 #{segment_name.capitalize} #{tires_text} #{size_display}:\n\n#{@response_formatter.format_price_segment_recommendations(recommendations, price_segment)}",
          preferences_updated: @conversation_manager.preferences,
          recommendations: recommendations,
          catalog_button: catalog_button_data,
          action: 'show_price_segment_recommendations'
        }
      else
        segment_name = @response_formatter.price_segment_name(price_segment)
        size_info = @conversation_manager.filters[:size][:full_size]
        season_info = @response_formatter.season_display_name(@conversation_manager.filters[:season]).downcase

        {
          message: "😔 #{t('price_segment_no_results', segment_name: segment_name, size: size_info, season: season_info)}",
          action: 'no_results'
        }
      end
    end

    # Handle recommendation request
    def handle_recommendation_request(_parameters, available_products)
      if @conversation_manager.filters[:size].blank?
        return {
          message: t('recommendations_needed_size'),
          next_step: 'size_request'
        }
      end

      if @conversation_manager.filters[:season].blank?
        return {
          message: t('season_question'),
          next_step: 'season_request'
        }
      end

      recommendations = get_tire_recommendations(available_products)

      if recommendations.any?
        catalog_button_data = get_catalog_button_data

        {
          message: @response_formatter.format_recommendations(
            recommendations,
            priority_type: @conversation_manager.preferences[:priority_type]
          ),
          recommendations: recommendations,
          catalog_button: catalog_button_data,
          action: 'show_recommendations_with_options'
        }
      else
        {
          message: "😔 #{t('no_results')}",
          action: 'no_results'
        }
      end
    end

    # Handle brand preference
    def handle_brand_preference(parameters)
      brands = parameters[:brands] || []
      @conversation_manager.update_filters(brands: brands)
      refresh_search_adapter

      {
        message: "✅ #{t('brands_accepted', brands: brands.join(', '))} #{@conversation_manager.get_next_question}",
        filters_updated: @conversation_manager.filters
      }
    end

    # Handle season preference
    def handle_season_preference(parameters, available_products)
      season = parameters[:season]
      normalized_season = @message_processor.normalize_season(season)

      @conversation_manager.update_filters(season: normalized_season)
      refresh_search_adapter

      if @conversation_manager.ready_for_recommendations?
        return show_season_recommendations(season, available_products)
      end

      {
        message: "✅ #{t('season_accepted', season: season)} #{@conversation_manager.get_next_question}",
        filters_updated: @conversation_manager.filters,
        next_step: @conversation_manager.determine_next_step
      }
    end

    def show_season_recommendations(season, available_products)
      if @conversation_manager.preferences[:price_segment].present?
        recommendations = get_price_segment_recommendations(available_products, @conversation_manager.preferences[:price_segment])
        return show_season_price_segment_results(season, recommendations) if recommendations.any?
      else
        recommendations = get_tire_recommendations(available_products)
        return show_season_standard_results(season, recommendations) if recommendations.any?
      end

      size_info = @conversation_manager.filters[:size] ? @conversation_manager.filters[:size][:full_size] : 'неизвестный'
      {
        message: "✅ #{t('season_accepted', season: season)}\n\n#{t('no_results_suggest_changes', size: size_info, season: season)}",
        filters_updated: @conversation_manager.filters,
        action: 'no_results',
        next_step: 'parameter_adjustment'
      }
    end

    def show_season_price_segment_results(season, recommendations)
      catalog_button_data = get_catalog_button_data
      segment_name = @response_formatter.price_segment_name(@conversation_manager.preferences[:price_segment])
      tires_text = @conversation_manager.locale == 'uk' ? 'шини розміру' : 'шины размера'
      size_display = @conversation_manager.filters[:size][:full_size]

      {
        message: "✅ #{t('season_accepted', season: season)}\n\n#{segment_name.capitalize} #{tires_text} #{size_display}:\n\n#{@response_formatter.format_price_segment_recommendations(recommendations, @conversation_manager.preferences[:price_segment])}",
        filters_updated: @conversation_manager.filters,
        preferences_updated: @conversation_manager.preferences,
        recommendations: recommendations,
        catalog_button: catalog_button_data,
        action: 'show_price_segment_recommendations'
      }
    end

    def show_season_standard_results(season, recommendations)
      catalog_button_data = get_catalog_button_data

      {
        message: "✅ #{t('season_accepted', season: season)}\n\n#{@response_formatter.format_recommendations(recommendations, priority_type: @conversation_manager.preferences[:priority_type])}",
        filters_updated: @conversation_manager.filters,
        recommendations: recommendations,
        catalog_button: catalog_button_data,
        action: 'show_recommendations_with_options'
      }
    end

    # Handle car model request
    def handle_car_model_request(parameters)
      car_model = parameters[:car_model]
      Rails.logger.info "🚗 Обработка запроса модели автомобиля: #{car_model}"

      @conversation_manager.update_preferences(car_model: car_model)

      message = "🚗 Понял, вам нужны шины для **#{car_model}**.\n\n"
      message += "Для точного подбора размера шин по марке автомобиля я рекомендую воспользоваться нашим специальным поиском:\n\n"
      message += "🔍 **Поиск шин по автомобилю**\n"
      message += "Там вы сможете выбрать точную модель и год выпуска для подбора правильного размера.\n\n"
      message += "Или укажите размер шин вручную в формате: **205/55R16**, **225/60R17**"

      {
        message: message,
        filters_updated: @conversation_manager.filters,
        preferences_updated: @conversation_manager.preferences,
        action: 'show_car_search_button',
        car_search_query: car_model
      }
    end

    # Handle budget constraint
    def handle_budget_constraint(parameters)
      @conversation_manager.update_filters(
        budget_max: parameters[:budget_max],
        budget_min: parameters[:budget_min]
      )
      refresh_search_adapter

      next_step = @conversation_manager.ready_for_recommendations? ? 'recommendation_request' : @conversation_manager.determine_next_step

      {
        message: "💰 #{t('budget_noted')} #{@conversation_manager.get_next_question}",
        filters_updated: @conversation_manager.filters,
        next_step: next_step
      }
    end

    # Handle technical question
    def handle_technical_question(_parameters, _available_products)
      {
        message: "🔧 Для детального технического консультирования рекомендую обратиться к нашим специалистам. А пока могу помочь с подбором шин по основным критериям.",
        next_step: 'general_question'
      }
    end

    # Handle general question
    def handle_general_question(_parameters, available_products)
      original_message = @conversation_manager.history.last&.dig(:message) || ''

      if @ai_client.available? && should_use_openai?(original_message)
        return handle_openai_chat_request(original_message, {}, available_products)
      end

      {
        message: "👋 #{t('welcome_message')}",
        next_step: 'size_request'
      }
    end

    # Handle continue discussion
    def handle_continue_discussion(_parameters)
      original_message = @conversation_manager.history.last&.dig(:message) || ''

      if @ai_client.available? && should_use_openai?(original_message)
        return handle_openai_chat_request(original_message, {}, nil)
      end

      {
        message: "💬 #{t('continue_discussion_ready')}",
        action: 'continue_discussion',
        next_step: 'discussion_mode'
      }
    end

    # Handle size guide request
    def handle_size_guide_request(_parameters)
      {
        message: @response_formatter.format_size_guide,
        action: 'size_guide_shown',
        next_step: 'size_request'
      }
    end

    # Handle brand comparison request
    def handle_brand_comparison_request(_parameters)
      {
        message: @response_formatter.format_brand_comparison,
        action: 'brand_comparison_shown',
        next_step: 'brand_selection'
      }
    end

    # Handle OpenAI chat request
    def handle_openai_chat_request(message, _parameters, _available_products)
      Rails.logger.info "🤖 Используем OpenAI для чата: #{message}"

      response = @ai_client.generate_tire_response(
        message,
        @conversation_manager.filters,
        @conversation_manager.locale
      )

      if response.present?
        Rails.logger.info "✅ OpenAI сгенерировал ответ для чата"
        {
          message: response,
          action: 'openai_response',
          next_step: 'continue_discussion'
        }
      else
        fallback_response
      end
    end

    # Helper methods
    def get_tire_recommendations(available_products = nil)
      @search_adapter.search_from_context(available_products)
    end

    def get_price_segment_recommendations(available_products, price_segment)
      @search_adapter.get_price_segment_recommendations(price_segment, available_products)
    end

    def get_catalog_button_data
      return nil unless @conversation_manager.filters[:size].present? && @conversation_manager.filters[:season].present?

      @response_formatter.catalog_button_data(
        @conversation_manager.filters[:size],
        @conversation_manager.filters[:season]
      )
    end

    def get_priority_description(priority)
      priority_type = @message_processor.normalize_priority(priority)

      descriptions = {
        'ru' => {
          'price_quality' => 'оптимальное соотношение цена/качество',
          'prestige' => 'престижность и статус бренда',
          'functionality' => 'максимальная функциональность',
          'balanced' => 'сбалансированный подход'
        },
        'uk' => {
          'price_quality' => 'оптимальне співвідношення ціна/якість',
          'prestige' => 'престижність і статус бренду',
          'functionality' => 'максимальна функціональність',
          'balanced' => 'збалансований підхід'
        }
      }

      lang_descriptions = descriptions[@conversation_manager.locale] || descriptions['ru']
      lang_descriptions[priority_type] || lang_descriptions['balanced']
    end

    def should_use_openai?(message)
      return false if message.blank?

      # Simple check for complex queries
      message.match?(/\?|сравни|порівня|лучше|краще|расскажи|розкажи|почему|чому/i)
    end

    def fallback_response
      {
        message: "😔 Извините, возникла техническая проблема. Онлайн-консультант временно недоступен. Попробуйте использовать стандартные фильтры поиска.",
        action: 'fallback'
      }
    end

    # Localization helper
    def t(key, **interpolations)
      message_template = messages[@conversation_manager.locale]&.[](key) || messages['ru'][key]
      return key unless message_template

      interpolations.each do |placeholder, value|
        message_template = message_template.gsub("%{#{placeholder}}", value.to_s)
      end

      message_template
    end

    def messages
      @messages ||= {
        'ru' => {
          'size_question' => 'Какой размер шин вам нужен?',
          'season_question' => 'Какие шины нужны - зимние, летние или всесезонные?',
          'size_accepted' => 'Отлично! Размер %{size} принят.',
          'size_not_recognized' => 'Не удалось распознать размер шин. Укажите размер в формате, например: 205/55R16 или 225 60 17',
          'welcome_message' => 'Привет! Я помогу вам выбрать оптимальные шины. Для начала укажите размер ваших шин, например: 205/55R16',
          'priority_accepted' => 'Понял, ваш приоритет - %{priority_description}.',
          'priority_options' => 'Выберите ваш приоритет:\n🏆 **Престижность** - топовые бренды и статус\n💰 **Цена/качество** - лучшее соотношение\n⚙️ **Функциональность** - максимальные технические характеристики',
          'recommendations_needed_size' => 'Для подбора оптимальных шин мне нужно знать размер. Укажите размер ваших шин, например: 205/55R16',
          'season_accepted' => 'Отлично, ищем %{season} шины.',
          'brands_accepted' => 'Учту ваши предпочтения по брендам: %{brands}.',
          'no_results' => 'К сожалению, по вашим критериям не найдено подходящих шин. Попробуйте изменить параметры поиска.',
          'no_results_suggest_changes' => 'К сожалению, по размеру %{size} и сезону %{season} шин не найдено. Попробуйте другой размер или проверьте наличие в других категориях.',
          'new_search_started' => 'Начинаем новый поиск шин!',
          'need_car_or_size_info' => 'Мне нужна информация о вашем автомобиле или размере шин. Укажите:\n🚗 **Марку и модель автомобиля** - например: Toyota Camry\n📏 **Или размер шин** - например: 205/55R16',
          'budget_noted' => 'Учту ваш бюджет.',
          'continue_discussion_ready' => 'Отлично! Давайте обсудим найденные варианты шин. Что бы вы хотели узнать подробнее?',
          'price_segment_request_size' => 'Понял, ищем %{segment_name} шины. Для подбора мне нужно знать:\n\n📏 **Размер шин** - например: 205/55R16, 225/60R17',
          'price_segment_request_season' => 'Понял, ищем %{segment_name} шины размера %{size}. Укажите сезон:\n\n❄️ **Зимние шины**\n☀️ **Летние шины**\n🔄 **Всесезонные шины**',
          'price_segment_no_results' => 'К сожалению, %{segment_name} шины размера %{size} для %{season} сезона не найдены.\n\nПопробуйте расширить критерии поиска или выбрать другой ценовой сегмент.'
        },
        'uk' => {
          'size_question' => 'Який розмір шин вам потрібен?',
          'season_question' => 'Які шини потрібні - зимові, літні чи всесезонні?',
          'size_accepted' => 'Відмінно! Розмір %{size} прийнято.',
          'size_not_recognized' => 'Не вдалося розпізнати розмір шин. Вкажіть розмір у форматі, наприклад: 205/55R16 або 225 60 17',
          'welcome_message' => 'Привіт! Я допоможу вам вибрати оптимальні шини. Для початку вкажіть розмір ваших шин, наприклад: 205/55R16',
          'priority_accepted' => 'Зрозумів, ваш пріоритет - %{priority_description}.',
          'priority_options' => 'Виберіть ваш пріоритет:\n🏆 **Престижність** - топові бренди та статус\n💰 **Ціна/якість** - найкраще співвідношення\n⚙️ **Функціональність** - максимальні технічні характеристики',
          'recommendations_needed_size' => 'Для підбору оптимальних шин мені потрібно знати розмір. Вкажіть розмір ваших шин, наприклад: 205/55R16',
          'season_accepted' => 'Відмінно, шукаємо %{season} шини.',
          'brands_accepted' => 'Врахую ваші переваги щодо брендів: %{brands}.',
          'no_results' => 'На жаль, за вашими критеріями не знайдено підходящих шин. Спробуйте змінити параметри пошуку.',
          'no_results_suggest_changes' => 'На жаль, за розміром %{size} та сезоном %{season} шин не знайдено. Спробуйте інший розмір або перевірте наявність в інших категоріях.',
          'new_search_started' => 'Розпочинаємо новий пошук шин!',
          'need_car_or_size_info' => 'Мені потрібна інформація про ваш автомобіль або розмір шин. Вкажіть:\n🚗 **Марку та модель автомобіля** - наприклад: Toyota Camry\n📏 **Або розмір шин** - наприклад: 205/55R16',
          'budget_noted' => 'Врахую ваш бюджет.',
          'continue_discussion_ready' => 'Відмінно! Давайте обговоримо знайдені варіанти шин. Що б ви хотіли дізнатися детальніше?',
          'price_segment_request_size' => 'Зрозумів, шукаємо %{segment_name} шини. Для підбору мені потрібно знати:\n\n📏 **Розмір шин** - наприклад: 205/55R16, 225/60R17',
          'price_segment_request_season' => 'Зрозумів, шукаємо %{segment_name} шини розміру %{size}. Вкажіть сезон:\n\n❄️ **Зимові шини**\n☀️ **Літні шини**\n🔄 **Всесезонні шини**',
          'price_segment_no_results' => 'На жаль, %{segment_name} шини розміру %{size} для %{season} сезону не знайдені.\n\nСпробуйте розширити критерії пошуку або вибрати інший ціновий сегмент.'
        }
      }
    end
  end
end
