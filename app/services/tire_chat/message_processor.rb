# frozen_string_literal: true

module TireChat
  # Message processor for intent detection and entity extraction
  # Handles user message analysis, intent recognition, and parameter extraction
  class MessageProcessor
    # Intent types
    INTENTS = %w[
      size_request
      season_preference
      priority_request
      price_segment_request
      recommendation_request
      brand_preference
      brand_comparison_request
      car_model_request
      size_guide_request
      new_search_request
      continue_discussion
      budget_constraint
      technical_question
      openai_chat_request
      general_question
      complex_request
    ].freeze

    # Season values
    SEASONS = {
      'summer' => /летн|літн|лето|літо|summer/i,
      'winter' => /зимн|зимов|зима|winter/i,
      'all_season' => /всесезон|всесезон|all.season/i
    }.freeze

    # Size pattern for tire sizes
    SIZE_PATTERNS = [
      /(\d{3})[\s\/\-]*(\d{2})[\s\/\-]*[rр]?(\d{1,2})/,
      /(\d{3})[\s]*(\d{2})[\s]*(?:на|на\s+)[\s]*(\d{1,2})/,
      /(\d{2,3})[\s\/\-]+(\d{2})[\s\/\-]+(\d{1,2})/
    ].freeze

    # New search patterns
    NEW_SEARCH_PATTERNS = [
      /шин[иы]?\s+(на|для)\s+\w+/,
      /рекоменд.*шин.*на\s+\w+/,
      /подбер.*шин.*для\s+\w+/,
      /рекоменд.*мне.*шин/,
      /что.*лучше.*для\s+\w+/,
      /хочу.*шин.*(?:на|для)\s+\w+/,
      /нужн.*шин.*(?:на|для)\s+\w+/,
      /шин.*(?:тигуан|бмв|ауди|тойота|фольксваген|хонда|мазда|митсубиси|ниссан|форд|шевроле|лада|дэу|киа|хёндай|renault|peugeot|citroen|opel|skoda|seat|volkswagen|audi|bmw|mercedes|honda|toyota|mazda|nissan|mitsubishi|ford|chevrolet|lada|daewoo|kia|hyundai)/i,
      /новый.*поиск/,
      /другой.*размер/,
      /начать.*сначала/,
      /забудь.*предыдущ/
    ].freeze

    attr_reader :ai_client

    def initialize(ai_client: nil)
      @ai_client = ai_client || AIClient.new
    end

    # Analyze user message and extract intent
    # @param message [String] User message
    # @param conversation_history [Array] Previous messages
    # @param current_filters [Hash] Current search filters
    # @return [Hash] Intent with type, parameters, and confidence
    def analyze(message, conversation_history: [], current_filters: {})
      return openai_chat_intent(message) if should_use_openai_for_chat?(message)

      simple_intent = analyze_simple_intent(message)
      return simple_intent if simple_intent[:confidence] > 0.8

      # Try AI analysis for uncertain cases
      if @ai_client.available?
        ai_intent = analyze_with_ai(message, conversation_history, current_filters)
        return ai_intent if ai_intent && ai_intent[:confidence] > 0.7
      end

      simple_intent.presence || general_question_intent
    end

    # Parse tire size from text
    # @param size_text [String] Text containing tire size
    # @return [Hash, nil] Parsed size with width, height, diameter
    def parse_tire_size(size_text)
      Rails.logger.info "🔍 Парсинг размера: '#{size_text}'"

      matches = size_text.match(/(\d{2,3})[\/\s]*(\d{2})[\/\s]*[rR]?(\d{1,2})/)

      if matches
        result = {
          width: matches[1].to_i,
          height: matches[2].to_i,
          diameter: matches[3].to_i,
          full_size: "#{matches[1]}/#{matches[2]}R#{matches[3]}"
        }
        Rails.logger.info "✅ Размер распознан: #{result}"
        result
      else
        Rails.logger.warn "❌ Не удалось распознать размер: '#{size_text}'"
        nil
      end
    end

    # Normalize season value to standard format
    # @param season_text [String] Season text in any language
    # @return [String] Normalized season (summer, winter, all_season)
    def normalize_season(season_text)
      season_lower = season_text.to_s.downcase

      SEASONS.each do |normalized, pattern|
        return normalized if season_lower.match?(pattern)
      end

      season_text
    end

    # Normalize priority value
    # @param priority_text [String] Priority text
    # @return [String] Normalized priority type
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

    # Detect car brand and model from message
    # @param message [String] User message
    # @return [Array<String>] Detected car brands/models
    def detect_car_brand(message)
      detected = []
      msg_lower = message.downcase

      car_brands_and_models.each do |brand, models|
        detected << brand if msg_lower.include?(brand)

        models.each do |model|
          model_regex = /\b#{Regexp.escape(model)}\b|\b#{Regexp.escape(model)}(?=\s)|(?<=\s)#{Regexp.escape(model)}\b/i

          next unless msg_lower.match?(model_regex)

          # Skip model if it's a number and message contains tire size pattern
          if model.match?(/^\d+$/) && msg_lower.match?(/\d+[\s\/\-]*\d+[\s\/\-]*\d+/)
            Rails.logger.info "🚫 Пропускаем модель '#{model}' - обнаружен паттерн размера шин"
            next
          end
          detected << "#{brand} #{model}"
        end
      end

      detected.uniq.sort_by(&:length).reverse
    end

    # Check if message indicates new search
    # @param message [String] User message
    # @return [Boolean] True if new search detected
    def new_search_detected?(message)
      msg_lower = message.to_s.downcase
      NEW_SEARCH_PATTERNS.any? { |pattern| msg_lower.match?(pattern) }
    end

    private

    def openai_chat_intent(message)
      {
        type: 'openai_chat_request',
        parameters: {},
        confidence: 1.0,
        original_message: message
      }
    end

    def general_question_intent
      { type: 'general_question', parameters: {}, confidence: 0.1 }
    end

    # Simple keyword-based intent analysis
    def analyze_simple_intent(message)
      msg = message.to_s.downcase
      parameters = {}
      intent_types = []

      # Detect new search
      intent_types << 'new_search_request' if new_search_detected?(message)

      # Detect tire size
      size_result = extract_tire_size(msg)
      if size_result
        parameters[:size] = size_result
        intent_types << 'size_request'
      end

      # Detect car model (only if no size found)
      unless intent_types.include?('size_request')
        car_brands = detect_car_brand(msg)
        if car_brands.any?
          parameters[:car_model] = car_brands.join(' ')
          intent_types << 'car_model_request'
        end
      end

      # Detect season
      season = extract_season(msg)
      if season
        parameters[:season] = season
        intent_types << 'season_preference'
      end

      # Detect brand comparison
      if msg.match?(/сравни.*бренд|порівня.*бренд|сравнить.*бренд|порівняти.*бренд|сравни.*марк|порівня.*марк|сравнить.*марк|порівняти.*марк|какой бренд лучше|який бренд кращий|какую марку выбрать|яку марку обрати/i)
        intent_types << 'brand_comparison_request'
      end

      # Detect price segment
      price_segment = extract_price_segment(msg)
      if price_segment
        parameters[:price_segment] = price_segment
        intent_types << 'price_segment_request'
      end

      # Detect priority
      priority = extract_priority(msg)
      if priority && !intent_types.include?('brand_comparison_request')
        parameters[:priority] = priority
        intent_types << 'priority_request'
      end

      # Detect recommendation request
      if msg.match?(/покажи|лучш|рекоменд|топ|вариант|подбер/i)
        intent_types << 'recommendation_request'
      end

      # Detect size guide request
      if msg.match?(/какой размер|як.* розмір|выбрать размер|обрати розмір|размер выбрать|розмір обрати|как найти размер|як знайти розмір/i)
        intent_types << 'size_guide_request'
      end

      # Detect new search request
      if msg.match?(/новый поиск|нов\w* поиск|начать заново|другие параметры|изменить критерии|сбросить|поиск другой|новий пошук|починати заново|інші параметри|скинути/i)
        intent_types << 'new_search_request'
      end

      # Detect continue discussion
      if msg.match?(/обсуд|подробн|детальн|сравн|больше информации|расскажи|особенности|характеристики|о модел|обговор|детальніше|порівня|більше інформації|розкажи|особливості|характеристики|про модел/i)
        intent_types << 'continue_discussion'
      end

      build_intent_result(intent_types, parameters)
    end

    def build_intent_result(intent_types, parameters)
      case intent_types.length
      when 0
        { type: 'general_question', parameters: parameters, confidence: 0.1 }
      when 1
        { type: intent_types.first, parameters: parameters, confidence: 0.9 }
      else
        {
          type: 'complex_request',
          parameters: parameters,
          intent_types: intent_types,
          confidence: 0.95
        }
      end
    end

    def extract_tire_size(msg)
      SIZE_PATTERNS.each do |pattern|
        next unless (size_match = msg.match(pattern))

        width = size_match[1].to_i
        next unless width >= 145 && width <= 345

        return "#{size_match[1]}/#{size_match[2]}R#{size_match[3]}"
      end
      nil
    end

    def extract_season(msg)
      SEASONS.each do |normalized, pattern|
        return normalized if msg.match?(pattern)
      end
      nil
    end

    def extract_price_segment(msg)
      if msg.match?(/дешев|дешёв|недорог|эконом|экономн|дёшев|дешеві|недорогі|cheap|budget(?!.*качеств)/i)
        'budget'
      elsif msg.match?(/(?<!не)дорог|премиум|дорож|эксклюзив|элитн|люкс|(?<!не)дорогі|преміум|premium|expensive/i)
        'premium'
      elsif msg.match?(/средн|обычн|нормальн|типов|стандарт|середн|звичайн|нормальн|середній|middle|average/i)
        'middle'
      elsif msg.match?(/бюджет/i) && !msg.match?(/цен.*качеств|соотношен/i)
        'budget'
      end
    end

    def extract_priority(msg)
      return 'цена/качество' if msg.match?(/цен.*качеств|соотношен/i)
      return 'престиж' if msg.match?(/престиж|статус/i)

      nil
    end

    # AI-based intent analysis for complex cases
    def analyze_with_ai(message, conversation_history, current_filters)
      prompt = build_intent_analysis_prompt(message, conversation_history, current_filters)
      @ai_client.analyze_intent(prompt)
    end

    def build_intent_analysis_prompt(message, conversation_history, current_filters)
      formatted_history = conversation_history.last(10).map do |entry|
        "#{entry[:role] == :user ? 'Пользователь' : 'Ассистент'}: #{entry[:message]}"
      end.join("\n")

      <<~PROMPT
        Ты - эксперт по автомобильным шинам. Проанализируй сообщение пользователя и определи его намерение.

        ВОЗМОЖНЫЕ НАМЕРЕНИЯ:
        1. "size_request" - пользователь указывает размер шин (например: "205/55/16", "225 60 R17")
        2. "priority_request" - пользователь указывает приоритеты (цена/качество, престиж, функциональность)
        3. "recommendation_request" - просит рекомендации (лучшие, оптимальные, топ варианты)
        4. "brand_preference" - упоминает конкретные бренды шин
        5. "season_preference" - указывает сезонность (зимние, летние, всесезонные)
        6. "budget_constraint" - указывает бюджет или ценовые ограничения
        7. "technical_question" - технические вопросы о характеристиках шин
        8. "new_search_request" - хочет начать новый поиск с нуля (сбросить параметры)
        9. "continue_discussion" - хочет обсудить уже найденные результаты подробнее
        10. "car_model_request" - упоминает марку/модель автомобиля для подбора шин
        11. "general_question" - общие вопросы

        ИСТОРИЯ РАЗГОВОРА:
        #{formatted_history}

        ТЕКУЩИЕ ФИЛЬТРЫ:
        #{current_filters.to_json}

        СООБЩЕНИЕ ПОЛЬЗОВАТЕЛЯ: #{message}

        Отвечай СТРОГО в JSON формате:
        {
          "type": "тип_намерения",
          "parameters": {
            "size": "размер шин если указан",
            "priority": "приоритет если указан",
            "brands": ["список брендов если указаны"],
            "season": "сезон если указан",
            "budget_max": "максимальный бюджет если указан",
            "budget_min": "минимальный бюджет если указан"
          },
          "confidence": 0.95
        }
      PROMPT
    end

    # Determine if message should be handled by OpenAI chat
    def should_use_openai_for_chat?(message)
      return false unless @ai_client.available?
      return false if message.blank?

      all_patterns = model_comparison_patterns + technical_patterns + expert_patterns +
                     tire_brand_patterns(message) + question_patterns

      all_patterns.any? { |pattern| message.match?(pattern) }
    end

    def model_comparison_patterns
      [
        /сравни.*модел|порівня.*модел|сравнить.*модел|порівняти.*модел/i,
        /сравни.*бренд|порівня.*бренд|сравнить.*бренд|порівняти.*бренд/i,
        /особенност|характеристик|відмінност|різниц/i,
        /против|проти|vs|versus/i,
        /лучше|кращ|лучш|краще/i,
        /чем отличает|чим відрізня/i,
        /в чем разниц|в чому різниц/i
      ]
    end

    def technical_patterns
      [
        /какие.*характеристи|які.*характеристи/i,
        /какие.*свойств|які.*властивост/i,
        /почему|чому|как работа|як працю/i,
        /разниц.*между|різниц.*між/i,
        /преимущест|переваг|недостат|недолік/i,
        /особенност|особливост/i,
        /важнее|важлив|важко/i,
        /качеств|якіст/i,
        /технолог|техніч/i,
        /состав|склад/i,
        /материал|матеріал/i
      ]
    end

    def expert_patterns
      [
        /рекомендац|порад|совет|підказ/i,
        /что лучше|що краще|что выбрать|що обрати/i,
        /стоит ли|чи варто|имеет смысл|має сенс/i,
        /посоветуй|порадь/i,
        /помоги выбрать|допоможи обрати/i,
        /какой.*подходит|який.*підходить/i,
        /для.*лучше|для.*краще/i
      ]
    end

    def question_patterns
      [
        /\?.*\?|\?$/i,
        /^(что|як|как|чому|почему|где|куда|когда|сколько|какой|який|чей|чий)/i,
        /можно|можна|нужно|потрібно|стоит|варто/i,
        /расскажи|розкажи|объясни|поясни/i,
        /подскажи|підкажи|скажи|скажіть/i
      ]
    end

    def tire_brand_patterns(message)
      tire_brands = %w[
        michelin continental bridgestone nokian pirelli
        goodyear dunlop hankook kumho toyo
        yokohama cooper falken nitto
        бриджестоун мишлен континенталь нокиан пирелли
        гудьир данлоп ханкук кумхо тойо
        йокохама купер фалькен нитто
        близак blizzak альпин alpin пилот pilot
        примаси primacy энерджи energy латитуд latitude
        турансо turanza потенца potenza дуелер dueler
      ]

      patterns = []
      tire_brands.each do |brand|
        next unless message.downcase.include?(brand.downcase)

        patterns << /#{Regexp.escape(brand)}/i
        patterns << /#{Regexp.escape(brand)}.*или|#{Regexp.escape(brand)}.*чи/i
        patterns << /#{Regexp.escape(brand)}.*против|#{Regexp.escape(brand)}.*проти/i
        patterns << /#{Regexp.escape(brand)}.*vs/i
      end
      patterns
    end

    # Car brands and models database
    def car_brands_and_models
      {
        'volkswagen' => %w[тигуан пассат гольф джетта поло туарег],
        'audi' => %w[а4 а6 q5 q7 а3 а8 tt],
        'bmw' => ['х5', 'х3', 'х1', 'серия 3', 'серия 5', 'серия 7'],
        'mercedes' => %w[c-class e-class s-class gla glc gle],
        'toyota' => ['камри', 'королла', 'рав4', 'прадо', 'ленд крузер', 'авенсис'],
        'honda' => ['аккорд', 'цивик', 'cr-v', 'пилот', 'инсайт'],
        'nissan' => ['альмера', 'кашкай', 'х-trail', 'мурано', 'патфайндер'],
        'hyundai' => %w[солярис элантра туксон creta],
        'kia' => %w[рио церато спортейдж соренто пиканто],
        'mazda' => ['mazda 3', 'mazda 6', 'cx-5', 'cx-3', 'cx-9'],
        'ford' => %w[фокус мондео куга экспедишн эскейп],
        'skoda' => %w[октавия фабия кодиак карок суперб],
        'renault' => %w[логан сандеро дастер каптур флюенс],
        'opel' => %w[астра корса инсигния мокка зафира],
        'peugeot' => %w[206 207 308 508 3008],
        'citroen' => %w[c3 c4 c5 berlingo xsara],
        'mitsubishi' => %w[лансер аутлендер паджеро l200 asx],
        'subaru' => %w[импреза форестер легаси аутбек xv],
        'volvo' => %w[s60 s90 xc60 xc90 v40],
        'lexus' => %w[rx nx gx lx es ls],
        'chevrolet' => %w[круз авео лачетти каптива тахо],
        'lada' => %w[веста гранта калина приора нива],
        'tesla' => ['model s', 'model 3', 'model x', 'model y']
      }
    end
  end
end
