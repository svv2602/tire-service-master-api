# frozen_string_literal: true

# Сервис для интеллектуального чата с пользователями по выбору оптимальных шин
class TireChatService
  include ActionView::Helpers::TextHelper

  # Контекст разговора
  attr_reader :conversation_history, :current_filters, :user_preferences, :locale

  def initialize(conversation_history: [], current_filters: {}, user_preferences: {}, locale: 'ru')
    @conversation_history = conversation_history || []
    @current_filters = initialize_filters(current_filters || {})
    @user_preferences = user_preferences || {}
    @locale = locale || 'ru'
    @openai_service = OpenaiService.new
  end

  # Основной метод обработки сообщения пользователя
  def process_message(user_message, available_products = nil, is_quick_question: false)
    Rails.logger.info "🤖 Обработка сообщения: #{user_message} (быстрый вопрос: #{is_quick_question})"
    
    # Если это быстрый вопрос, сбрасываем все фильтры и предпочтения
    if is_quick_question
      Rails.logger.info "🔄 Сброс параметров для быстрого вопроса"
      reset_filters
      @conversation_history = [] # Очищаем историю разговора
    end
    
    # Добавляем сообщение пользователя в историю
    add_to_history(:user, user_message)
    
    # Анализируем намерение пользователя
    intent = analyze_user_intent(user_message)
    Rails.logger.info "🎯 Определено намерение: #{intent[:type]}"
    
    # Обрабатываем намерение и генерируем ответ
    response = handle_intent(intent, available_products)
    
    # Добавляем ответ ассистента в историю
    add_to_history(:assistant, response[:message])
    
    response
  rescue => e
    Rails.logger.error "❌ Ошибка в TireChatService: #{e.message}"
    fallback_response
  end

  private

  # Инициализация фильтров с базовой структурой
  def initialize_filters(filters)
    {
      size: nil,
      season: nil,
      budget_min: nil,
      budget_max: nil,
      brand_preferences: nil,
      priority_type: nil
    }.merge(filters)
  end

  # Анализ намерения пользователя через OpenAI
  def analyze_user_intent(message)
    # Сначала пробуем простой анализ по ключевым словам
    simple_intent = analyze_simple_intent(message)
    return simple_intent if simple_intent[:confidence] > 0.8
    
    # Если не уверены, используем OpenAI
    prompt = build_intent_analysis_prompt(message)
    
    response = @openai_service.send(:chat_completion, prompt)
    content = response.dig("choices", 0, "message", "content")
    
    if content
      parsed_intent = parse_intent_response(content)
      Rails.logger.info "📝 Распознанное намерение: #{parsed_intent}"
      parsed_intent
    else
      simple_intent.presence || { type: 'general_question', parameters: {} }
    end
  rescue => e
    Rails.logger.error "❌ Ошибка анализа намерения: #{e.message}"
    simple_intent.presence || { type: 'general_question', parameters: {} }
  end

  # Простой анализ по ключевым словам
  def analyze_simple_intent(message)
    msg = message.to_s.downcase
    parameters = {}
    intent_types = []
    
    # Размер шин - ПРИОРИТЕТ ПЕРВЫЙ, улучшенные паттерны
    # Поддерживаем форматы: "195/65R15", "195 65 15", "195 65 на 15", "195-65-15"
    size_patterns = [
      /(\d{3})[\s\/\-]*(\d{2})[\s\/\-]*[rр]?(\d{1,2})/,  # Стандартный: 195/65R15
      /(\d{3})[\s]*(\d{2})[\s]*(?:на|на\s+)[\s]*(\d{1,2})/,  # С "на": 195 65 на 15
      /(\d{2,3})[\s\/\-]+(\d{2})[\s\/\-]+(\d{1,2})/,  # Общий: 195/65/15 или 205-55-16
    ]
    
    size_patterns.each do |pattern|
      if size_match = msg.match(pattern)
        # Проверяем, что это действительно размер шин (ширина от 145 до 345)
        width = size_match[1].to_i
        if width >= 145 && width <= 345
          parameters[:size] = "#{size_match[1]}/#{size_match[2]}R#{size_match[3]}"
          intent_types << 'size_request'
          Rails.logger.info "🎯 Распознан размер шин: #{parameters[:size]} из '#{message}'"
          break  # Найден размер, прекращаем поиск
        end
      end
    end
    
    # Распознавание марок автомобилей - ТОЛЬКО если НЕ найден размер шин
    if !intent_types.include?('size_request')
      car_brands = detect_car_brand(msg)
      if car_brands.any?
        parameters[:car_model] = car_brands.join(' ')
        intent_types << 'car_model_request'
      end
    end
    
    # Сезонность
    if msg.match?(/летн|літн|лето|літо|summer/i)
      parameters[:season] = 'летние'
      intent_types << 'season_preference'
    elsif msg.match?(/зимн|зимов|зима|winter/i)
      parameters[:season] = 'зимние'
      intent_types << 'season_preference'
    elsif msg.match?(/всесезон|всесезон|all.season/i)
      parameters[:season] = 'всесезонные'
      intent_types << 'season_preference'
    end
    
    # Приоритеты
    if msg.match?(/цен.*качеств|соотношен|бюджет/i)
      parameters[:priority] = 'цена/качество'
      intent_types << 'priority_request'
    elsif msg.match?(/престиж|статус|бренд/i)
      parameters[:priority] = 'престиж'
      intent_types << 'priority_request'
    end
    
    # Запрос рекомендаций
    if msg.match?(/покажи|лучш|рекоменд|топ|вариант|подбер/i)
      intent_types << 'recommendation_request'
    end
    
    # Запрос на новый поиск
    if msg.match?(/новый поиск|нов\w* поиск|начать заново|другие параметры|изменить критерии|сбросить|поиск другой|новий пошук|починати заново|інші параметри|скинути/i)
      intent_types << 'new_search_request'
    end
    
    # Продолжение обсуждения результатов
    if msg.match?(/обсуд|подробн|детальн|сравн|больше информации|расскажи|особенности|характеристики|о модел|обговор|детальніше|порівня|більше інформації|розкажи|особливості|характеристики|про модел/i)
      intent_types << 'continue_discussion'
    end
    
    # Возвращаем комплексное намерение или самое приоритетное
    if intent_types.length > 1
      return { 
        type: 'complex_request', 
        parameters: parameters, 
        intent_types: intent_types,
        confidence: 0.95 
      }
    elsif intent_types.length == 1
      return { 
        type: intent_types.first, 
        parameters: parameters, 
        confidence: 0.9 
      }
    end
    
    { type: 'general_question', parameters: parameters, confidence: 0.1 }
  end

  # Построение промпта для анализа намерения
  def build_intent_analysis_prompt(message)
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
      #{format_conversation_for_prompt}

      ТЕКУЩИЕ ФИЛЬТРЫ:
      #{@current_filters.to_json}

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

  # Парсинг ответа OpenAI с намерением
  def parse_intent_response(content)
    # Очищаем markdown если есть
    json_content = content.strip
    if json_content.start_with?('```json') && json_content.end_with?('```')
      json_content = json_content.gsub(/\A```json\n?/, '').gsub(/\n?```\z/, '')
    elsif json_content.start_with?('```') && json_content.end_with?('```')
      json_content = json_content.gsub(/\A```\n?/, '').gsub(/\n?```\z/, '')
    end
    
    JSON.parse(json_content).with_indifferent_access
  rescue JSON::ParserError => e
    Rails.logger.error "❌ Ошибка парсинга намерения: #{e.message}, контент: #{content}"
    { type: 'general_question', parameters: {}, confidence: 0.1 }
  end

  # Обработка намерения и генерация ответа
  def handle_intent(intent, available_products)
    case intent[:type]
    when 'complex_request'
      handle_complex_request(intent, available_products)
    when 'size_request'
      handle_size_request(intent[:parameters])
    when 'priority_request'
      handle_priority_request(intent[:parameters])
    when 'recommendation_request'
      handle_recommendation_request(intent[:parameters], available_products)
    when 'brand_preference'
      handle_brand_preference(intent[:parameters])
    when 'season_preference'
      handle_season_preference(intent[:parameters])
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
    else
      handle_general_question(intent[:parameters], available_products)
    end
  end

  # Обработка комплексного запроса
  def handle_complex_request(intent, available_products)
    parameters = intent[:parameters]
    intent_types = intent[:intent_types] || []
    
    Rails.logger.info "🎯 Обработка комплексного запроса: #{intent_types.join(', ')}"
    
    # Обновляем фильтры и предпочтения
    update_filters_from_parameters(parameters)
    
    # Определяем, что показать пользователю
    if intent_types.include?('recommendation_request') || ready_for_recommendations?
      # Если просят рекомендации или есть все данные - показываем рекомендации
      Rails.logger.info "🎯 Все данные готовы, показываем рекомендации"
      
      # Формируем сообщение подтверждения параметров
      confirmations = []
      if parameters[:size].present?
        confirmations << "размер #{parameters[:size]}"
      end
      if parameters[:season].present?
        confirmations << "#{parameters[:season]} шины"
      end
      if parameters[:priority].present?
        confirmations << "приоритет: #{parameters[:priority]}"
      end
      
      # Получаем рекомендации
      recommendations = get_tire_recommendations(available_products)
      
      if recommendations.any?
        catalog_button_data = get_catalog_button_data if @current_filters[:size].present? && @current_filters[:season].present?
        confirmation_msg = confirmations.any? ? "✅ Принято: #{confirmations.join(', ')}.\n\n" : ""
        
        {
          message: "#{confirmation_msg}#{format_recommendations(recommendations)}",
          filters_updated: @current_filters,
          preferences_updated: @user_preferences,
          recommendations: recommendations,
          catalog_button: catalog_button_data,
          action: 'show_recommendations_with_options'
        }
      else
        confirmation_msg = confirmations.any? ? "✅ Принято: #{confirmations.join(', ')}.\n\n" : ""
        {
          message: "#{confirmation_msg}😔 #{localized_message('no_results')}",
          filters_updated: @current_filters,
          preferences_updated: @user_preferences,
          action: 'no_results'
        }
      end
    else
      # Иначе подтверждаем принятые параметры
      confirmations = []
      
      if parameters[:size].present?
        confirmations << "размер #{parameters[:size]}"
      end
      
      if parameters[:season].present?
        confirmations << "#{parameters[:season]} шины"
      end
      
      if parameters[:priority].present?
        confirmations << "приоритет: #{parameters[:priority]}"
      end
      
      message = "✅ Принято: #{confirmations.join(', ')}. #{get_next_question_for_context}"
      
      {
        message: message,
        filters_updated: @current_filters,
        preferences_updated: @user_preferences,
        next_step: determine_next_step
      }
    end
  end

  # Обновление фильтров из параметров
  def update_filters_from_parameters(parameters)
    if parameters[:size].present?
      @current_filters[:size] = parse_tire_size(parameters[:size])
    end
    
    if parameters[:season].present?
      normalized_season = case parameters[:season].to_s.downcase
      when /летн|літн|лето|літо|summer/
        'summer'
      when /зимн|зимов|зима|winter/
        'winter'
      when /всесезон|всесезон|all.season/
        'all_season'
      else
        parameters[:season]
      end
      @current_filters[:season] = normalized_season
      Rails.logger.info "🔄 Нормализация сезона в update_filters: '#{parameters[:season]}' → '#{normalized_season}'"
    end
    
    if parameters[:priority].present?
      @user_preferences[:priority_type] = normalize_priority(parameters[:priority])
    end
    
    Rails.logger.info "🔧 Обновленные фильтры: #{@current_filters}"
    Rails.logger.info "🎯 Обновленные предпочтения: #{@user_preferences}"
  end

  # Обработка запроса размера шин
  def handle_size_request(parameters)
    size = parameters[:size]
    if size.present?
      @current_filters[:size] = parse_tire_size(size)
      
      # Если у нас есть размер и сезон - сразу ищем и показываем результат
      if ready_for_recommendations?
        recommendations = get_tire_recommendations
        
        if recommendations.any?
          catalog_button_data = get_catalog_button_data if @current_filters[:size].present? && @current_filters[:season].present?
          
          return {
            message: "✅ #{localized_message('size_accepted', size: size)}\n\n#{format_recommendations(recommendations)}",
            filters_updated: @current_filters,
            recommendations: recommendations,
            catalog_button: catalog_button_data,
            action: 'show_recommendations'
          }
        else
          size_info = @current_filters[:size][:full_size]
          season_info = @current_filters[:season]
          return {
            message: "✅ #{localized_message('size_accepted', size: size)}\n\n#{localized_message('no_results_suggest_changes', size: size_info, season: season_info)}",
            filters_updated: @current_filters,
            action: 'no_results',
            next_step: 'parameter_adjustment'
          }
        end
      else
        {
          message: "✅ #{localized_message('size_accepted', size: size)} #{get_next_question_for_context}",
          filters_updated: @current_filters,
          next_step: get_next_step_after_size
        }
      end
    else
      {
        message: "🤔 #{localized_message('size_not_recognized')}",
        next_step: 'size_request'
      }
    end
  end

  # Обработка запроса приоритетов
  def handle_priority_request(parameters)
    priority = parameters[:priority]
    if priority.present?
      @user_preferences[:priority_type] = normalize_priority(priority)
      next_step = ready_for_recommendations? ? 'recommendation_request' : determine_next_step
      {
        message: "👍 #{localized_message('priority_accepted', priority_description: get_priority_description(priority))} #{get_next_question_for_context}",
        preferences_updated: @user_preferences,
        next_step: next_step
      }
    else
      {
        message: localized_message('priority_options'),
        next_step: 'priority_request'
      }
    end
  end

  # Обработка запроса рекомендаций
  def handle_recommendation_request(parameters, available_products)
    # Проверяем есть ли все обязательные данные
    if @current_filters[:size].blank?
      return {
        message: localized_message('recommendations_needed_size'),
        next_step: 'size_request'
      }
    end
    
    if @current_filters[:season].blank?
      return {
        message: localized_message('season_question'),
        next_step: 'season_request'
      }
    end

    recommendations = get_tire_recommendations(available_products)
    
    if recommendations.any?
      catalog_button_data = get_catalog_button_data if @current_filters[:size].present? && @current_filters[:season].present?
      
      {
        message: format_recommendations(recommendations),
        recommendations: recommendations,
        catalog_button: catalog_button_data,
        action: 'show_recommendations_with_options'
      }
    else
      {
        message: "😔 #{localized_message('no_results')}",
        action: 'no_results'
      }
    end
  end

  # Получение рекомендаций на основе фильтров и предпочтений
  def get_tire_recommendations(available_products = nil)
    Rails.logger.info "🔍 Поиск рекомендаций с фильтрами: #{@current_filters}"
    
    # Если продукты не переданы, ищем в базе
    products_scope = available_products || SupplierTireProduct.in_stock.includes(:tire_brand, :tire_model, :country, :supplier)
    initial_count = products_scope.count
    Rails.logger.info "📦 Начальное количество товаров в наличии: #{initial_count}"
    
    # Применяем фильтры
    if @current_filters[:size].present?
      size = @current_filters[:size]
      Rails.logger.info "📏 Применяю фильтр размера: #{size[:width]}/#{size[:height]}R#{size[:diameter]}"
      products_scope = products_scope.by_size(size[:width], size[:height], size[:diameter])
      size_count = products_scope.count
      Rails.logger.info "📏 После фильтра размера: #{size_count} товаров"
    end
    
    if @current_filters[:season].present?
      Rails.logger.info "❄️ Применяю фильтр сезона: #{@current_filters[:season]}"
      products_scope = products_scope.by_season(@current_filters[:season])
      season_count = products_scope.count
      Rails.logger.info "❄️ После фильтра сезона: #{season_count} товаров"
    end
    
    if @current_filters[:brands].present?
      brand_ids = TireBrand.where(normalized_name: @current_filters[:brands]).pluck(:id)
      products_scope = products_scope.where(tire_brand_id: brand_ids)
      Rails.logger.info "🏷️ После фильтра брендов: #{products_scope.count} товаров"
    end
    
    all_products = products_scope.limit(200) # Увеличиваем лимит для лучшего группирования
    Rails.logger.info "🎯 Всего товаров для группировки: #{all_products.count}"
    
    # Если нет товаров после фильтрации, возвращаем пустой массив
    if all_products.count == 0
      Rails.logger.warn "⚠️ Нет товаров после применения фильтров"
      return []
    end
    
    # Группируем товары по уникальным параметрам шин
    grouped_products = group_products_by_tire_params(all_products)
    Rails.logger.info "🔄 Создано #{grouped_products.count} групп уникальных шин"
    
    # Получаем рекомендации с группировкой
    priority_type = @user_preferences[:priority_type] || 'balanced'
    recommendations = calculate_grouped_recommendations(grouped_products, priority_type)
    
    Rails.logger.info "🎯 Итоговых рекомендаций: #{recommendations.length}"
    recommendations
  end

  # Группировка товаров по параметрам шин (размер + бренд + модель + индексы)
  def group_products_by_tire_params(products)
    grouped = products.group_by do |product|
      {
        brand: product.brand_normalized,
        model: product.original_model,
        width: product.width,
        height: product.height,
        diameter: product.diameter,
        load_index: product.load_index,
        speed_index: product.speed_index,
        season: product.season
      }
    end
    
    grouped.map do |tire_params, tire_products|
      # Выбираем самое дешевое предложение из группы
      cheapest_product = tire_products.min_by { |p| p.price_uah || Float::INFINITY }
      
      {
        tire_params: tire_params,
        best_product: cheapest_product,
        all_products: tire_products,
        suppliers_count: tire_products.map(&:supplier_id).uniq.count,
        price_range: {
          min: tire_products.map(&:price_uah).compact.min,
          max: tire_products.map(&:price_uah).compact.max
        }
      }
    end
  end

  # Расчет рекомендаций для сгруппированных товаров
  def calculate_grouped_recommendations(grouped_products, priority_type)
    begin
      # Создаем рекомендации для лучших продуктов из каждой группы
      recommendations = grouped_products.map do |group|
        product = group[:best_product]
        
        # Рассчитываем оптимальность для лучшего продукта
        optimality_result = TireOptimalityCalculator.calculate_batch_optimality(
          [product], 
          priority_type: priority_type
        ).first
        
        # Добавляем информацию о группе
        score = optimality_result ? optimality_result[:optimality_score] : 7.0
        reasons = optimality_result ? optimality_result[:recommendation_reasons] : ['Доступен в наличии']
        
        # Добавляем причины связанные с группировкой
        if group[:suppliers_count] > 1
          reasons << "Доступен у #{group[:suppliers_count]} поставщиков"
        end
        
        if group[:price_range][:min] && group[:price_range][:max] && 
           group[:price_range][:max] > group[:price_range][:min]
          savings = group[:price_range][:max] - group[:price_range][:min]
          reasons << "Экономия до #{savings.to_i} грн по сравнению с другими поставщиками"
        end
        
        {
          product: product,
          optimality_score: score,
          recommendation_reasons: reasons,
          tire_group_info: group[:tire_params],
          suppliers_count: group[:suppliers_count],
          price_savings: group[:price_range][:max] ? (group[:price_range][:max] - group[:price_range][:min]).to_i : 0
        }
      end
      
      # Сортируем по оптимальности и цене
      recommendations.sort_by! do |rec|
        [-rec[:optimality_score], rec[:product].price_uah || Float::INFINITY]
      end
      
      # Возвращаем топ-5
      recommendations.first(5)
      
    rescue => e
      Rails.logger.error "❌ Ошибка при расчете групповой оптимальности: #{e.message}"
      
      # Fallback: простая сортировка по цене
      grouped_products.sort_by { |group| group[:best_product].price_uah || Float::INFINITY }
                     .first(5)
                     .map do |group|
        {
          product: group[:best_product],
          optimality_score: 7.0,
          recommendation_reasons: ['Доступен в наличии', 'Лучшая цена в категории'],
          tire_group_info: group[:tire_params],
          suppliers_count: group[:suppliers_count],
          price_savings: group[:price_range][:max] ? (group[:price_range][:max] - group[:price_range][:min]).to_i : 0
        }
      end
    end
  end

  # Форматирование рекомендаций для пользователя
  def format_recommendations(recommendations)
    if recommendations.empty?
      return "😔 #{localized_message('no_results')}"
    end

    message = "🎯 **#{localized_message('recommendations_title')}**\n\n"
    
    recommendations.first(5).each_with_index do |item, index|
      product = item[:product]
      score = item[:optimality_score]
      suppliers_count = item[:suppliers_count] || 1
      price_savings = item[:price_savings] || 0
      
      # Основная информация о шине
      message += "**#{index + 1}. #{product.brand_normalized} #{product.original_model}** "
      message += "#{product.width}/#{product.height}R#{product.diameter} #{product.load_index}#{product.speed_index}\n"
      
      # Цена и основные характеристики
      message += "   💰 **#{product.formatted_price}** | ⭐ Рейтинг: #{score.round(1)}/10"
      
      # Информация о поставщиках
      if suppliers_count > 1
        message += " | 🏪 У #{suppliers_count} поставщиков"
      end
      
      # Экономия
      if price_savings > 0
        message += " | 💸 Экономия до #{price_savings} грн"
      end
      
      message += "\n"
      
      # Страна производства
      if product.country.present?
        country_name = product.country.respond_to?(:name) ? product.country.name : product.country.to_s
        message += "   🌍 #{country_name} | "
      end
      
      # Поставщик (лучшее предложение)
      if product.supplier.present?
        message += "🏷️ #{product.supplier.name}"
      end
      
      message += "\n"
      
      # Причины рекомендации
      reasons = item[:recommendation_reasons] || ['Доступен в наличии']
      message += "   ✨ *#{reasons.join(', ')}*\n\n"
    end
    
    message += "💡 **#{localized_message('recommendation_explanation_title')}**\n"
    message += get_recommendation_explanation_grouped
    message += "\n\n"
    
    # Добавляем кнопку каталога если есть фильтры размера и сезона
    if @current_filters[:size].present? && @current_filters[:season].present?
      message += format_catalog_button
      message += "\n\n"
    end
    
    # Добавляем опции для продолжения диалога
    message += format_continuation_options
    
    message
  end

  # Объяснение логики рекомендаций с учетом группировки
  def get_recommendation_explanation_grouped
    explanation = "Показаны лучшие предложения для каждой уникальной модели шин. "
    explanation += "Для каждой модели выбрана самая низкая цена среди всех поставщиков.\n\n"
    
    case @user_preferences[:priority_type]
    when 'price_quality'
      explanation += "🎯 **Приоритет: цена/качество** - выбраны модели с лучшим соотношением цены и характеристик."
    when 'prestige'
      explanation += "🏆 **Приоритет: престиж** - рекомендованы премиум-бренды и топовые модели."
    when 'functionality'
      explanation += "⚙️ **Приоритет: функциональность** - упор на технические характеристики и эксплуатационные качества."
    else
      explanation += "⚖️ **Сбалансированный подход** - учтены цена, качество и репутация бренда."
    end
    
    explanation
  end

  # Форматирование кнопки каталога для просмотра всех размеров
  def format_catalog_button
    size_info = @current_filters[:size]
    season_info = @current_filters[:season]
    
    size_display = "#{size_info[:width]}/#{size_info[:height]}R#{size_info[:diameter]}"
    season_display = get_season_display_name(season_info)
    
    message = "🔍 **Вы можете также просмотреть все размеры:**\n\n"
    message += "📋 Показать все варианты: **#{size_display} #{season_display}**"
    
    message
  end

  # Получение отображаемого названия сезона
  def get_season_display_name(season)
    case season
    when 'winter'
      'Зимние'
    when 'summer'
      'Летние'  
    when 'all_season'
      'Всесезонные'
    else
      season.to_s.capitalize
    end
  end

  # Получение данных для кнопки каталога
  def get_catalog_button_data
    return nil unless @current_filters[:size].present? && @current_filters[:season].present?
    
    size_info = @current_filters[:size]
    season_info = @current_filters[:season]
    
    {
      text: "📋 Показать все варианты: #{size_info[:width]}/#{size_info[:height]}R#{size_info[:diameter]} #{get_season_display_name(season_info)}",
      filters: {
        width: size_info[:width],
        height: size_info[:height], 
        diameter: size_info[:diameter],
        season: season_info
      },
      action: 'apply_catalog_filters'
    }
  end

  # Объяснение логики рекомендаций
  def get_recommendation_explanation
    priority = @user_preferences[:priority_type]
    
    case priority
    when 'price_quality'
      "Учитывая ваш приоритет соотношения цена/качество, я выбрал шины с высоким рейтингом качества по разумной цене."
    when 'prestige'
      "Согласно вашему запросу на престижность, рекомендую топовые бренды с отличной репутацией."
    when 'functionality'
      "Исходя из вашего фокуса на функциональность, это шины с лучшими техническими характеристиками."
    else
      "Рекомендации основаны на сбалансированной оценке всех характеристик шин."
    end
  end

  # Форматирование опций для продолжения диалога
  def format_continuation_options
    "🔄 **#{localized_message('continuation_options_title')}**\n\n" +
    "💬 #{localized_message('continue_discussion_option')}\n" +
    "🔍 #{localized_message('new_search_option')}\n\n" +
    "#{localized_message('continuation_prompt')}"
  end

  # Получение следующего вопроса в зависимости от контекста
  def get_next_question_for_context
    Rails.logger.info "🔍 Проверка параметров для next_question: #{@current_filters.inspect}"
    
    missing_params = []
    
    # Проверяем обязательные параметры
    if @current_filters[:size].blank?
      missing_params << localized_message('missing_size_param')
      Rails.logger.info "📏 Отсутствует размер шин"
    end
    
    if @current_filters[:season].blank?
      missing_params << localized_message('missing_season_param')
      Rails.logger.info "🌤️ Отсутствует сезон шин"
    end
    
    if missing_params.any?
      # Формируем конкретные подсказки о недостающих параметрах
      result = "#{localized_message('need_more_info')}\n#{missing_params.join("\n")}"
      Rails.logger.info "❓ Запрашиваем недостающие параметры: #{missing_params.length}"
      return result
    else
      # Если основные параметры есть, готовы к рекомендациям
      Rails.logger.info "✅ Все параметры готовы для рекомендаций"
      return localized_message('ready_to_recommend')
    end
  end
  
  # Проверка готовности к рекомендациям
  def ready_for_recommendations?
    @current_filters[:size].present? && @current_filters[:season].present?
  end

  # Сброс всех фильтров для начала нового поиска
  def reset_filters
    @current_filters = {
      size: nil,
      season: nil,
      budget_min: nil,
      budget_max: nil,
      brand_preferences: nil,
      priority_type: nil
    }
    @user_preferences = {}
  end

  # Нормализация приоритета пользователя
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

  # Описание приоритета для пользователя
  def get_priority_description(priority)
    priority_type = normalize_priority(priority)
    
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
    
    lang_descriptions = descriptions[@locale] || descriptions['ru']
    lang_descriptions[priority_type] || lang_descriptions['balanced']
  end

  # Распознавание марок и моделей автомобилей
  def detect_car_brand(message)
    car_brands_and_models = {
      # Популярные марки
      'volkswagen' => ['тигуан', 'пассат', 'гольф', 'джетта', 'поло', 'туарег'],
      'audi' => ['а4', 'а6', 'q5', 'q7', 'а3', 'а8', 'tt'],
      'bmw' => ['х5', 'х3', 'х1', 'серия 3', 'серия 5', 'серия 7'],
      'mercedes' => ['c-class', 'e-class', 's-class', 'gla', 'glc', 'gle'],
      'toyota' => ['камри', 'королла', 'рав4', 'прадо', 'ленд крузер', 'авенсис'],
      'honda' => ['аккорд', 'цивик', 'cr-v', 'пилот', 'инсайт'],
      'nissan' => ['альмера', 'кашкай', 'х-trail', 'мурано', 'патфайндер'],
      'hyundai' => ['солярис', 'элантра', 'туксон', 'санта фе', 'creta'],
      'kia' => ['рио', 'церато', 'спортейдж', 'соренто', 'пиканто'],
      'mazda' => ['mazda 3', 'mazda 6', 'cx-5', 'cx-3', 'cx-9'],
      'ford' => ['фокус', 'мондео', 'куга', 'экспедишн', 'эскейп'],
      'skoda' => ['октавия', 'фабия', 'кодиак', 'карок', 'суперб'],
      'renault' => ['логан', 'сандеро', 'дастер', 'каптур', 'флюенс'],
      'opel' => ['астра', 'корса', 'инсигния', 'мокка', 'зафира'],
      'peugeot' => ['206', '207', '308', '508', '3008'],
      'citroen' => ['c3', 'c4', 'c5', 'berlingo', 'xsara'],
      'mitsubishi' => ['лансер', 'аутлендер', 'паджеро', 'l200', 'asx'],
      'subaru' => ['импреза', 'форестер', 'легаси', 'аутбек', 'xv'],
      'volvo' => ['s60', 's90', 'xc60', 'xc90', 'v40'],
      'lexus' => ['rx', 'nx', 'gx', 'lx', 'es', 'ls'],
      'infiniti' => ['qx50', 'qx70', 'q50', 'qx80', 'fx'],
      'acura' => ['mdx', 'rdx', 'tlx', 'ilx'],
      'land rover' => ['range rover', 'discovery', 'defender', 'freelander'],
      'jeep' => ['cherokee', 'grand cherokee', 'compass', 'wrangler'],
      'chevrolet' => ['круз', 'авео', 'лачетти', 'каптива', 'тахо'],
      'cadillac' => ['escalade', 'xt5', 'ats', 'cts'],
      'porsche' => ['cayenne', 'macan', '911', 'panamera'],
      'jaguar' => ['xf', 'xe', 'f-pace', 'e-pace'],
      'alfa romeo' => ['giulia', 'stelvio', '159', '147'],
      'fiat' => ['500', 'panda', 'tipo', 'doblo'],
      'lada' => ['веста', 'гранта', 'калина', 'приора', 'нива'],
      'uaz' => ['патриот', 'хантер', 'буханка']
    }
    
    detected = []
    msg_lower = message.downcase
    
    car_brands_and_models.each do |brand, models|
      # Проверяем марку
      if msg_lower.include?(brand)
        detected << brand
      end
      
      # Проверяем модели - избегаем ложных срабатываний на числа размеров шин
      models.each do |model|
        if msg_lower.include?(model)
          # Дополнительная проверка: если модель - это число, проверяем контекст
          if model.match?(/^\d+$/) && msg_lower.match?(/\d+[\s\/\-]*\d+[\s\/\-]*\d+/)
            # Если в сообщении есть паттерн размера шин (3 числа), пропускаем модель-число
            Rails.logger.info "🚫 Пропускаем модель '#{model}' - обнаружен паттерн размера шин"
            next
          end
          detected << "#{brand} #{model}"
        end
      end
    end
    
    # Убираем дубликаты и сортируем по длине (более специфичные первыми)
    detected.uniq.sort_by(&:length).reverse
  end

  # Парсинг размера шин из текста
  def parse_tire_size(size_text)
    Rails.logger.info "🔍 Парсинг размера: '#{size_text}'"
    
    # Паттерны: "205/55R16", "205 55 16", "205/55/16", включая 2-значные ширины
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

  # Добавление сообщения в историю разговора
  def add_to_history(role, message)
    @conversation_history << {
      role: role,
      message: message,
      timestamp: Time.current
    }
    
    # Ограничиваем историю последними 20 сообщениями
    @conversation_history = @conversation_history.last(20)
  end

  # Форматирование истории для промпта
  def format_conversation_for_prompt
    @conversation_history.last(10).map do |entry|
      "#{entry[:role] == :user ? 'Пользователь' : 'Ассистент'}: #{entry[:message]}"
    end.join("\n")
  end

  # Fallback ответ при ошибках
  def fallback_response
    {
      message: "😔 Извините, возникла техническая проблема. Онлайн-консультант временно недоступен. Попробуйте использовать стандартные фильтры поиска.",
      action: 'fallback'
    }
  end

  # Обработка остальных типов намерений (заглушки для расширения)
  def handle_brand_preference(parameters)
    brands = parameters[:brands] || []
    @current_filters[:brands] = brands.map(&:downcase)
    
    {
      message: "✅ #{localized_message('brands_accepted', brands: brands.join(', '))} #{get_next_question_for_context}",
      filters_updated: @current_filters
    }
  end

  def handle_season_preference(parameters)
    season = parameters[:season]
    
    # Нормализуем сезон - используем значения из SupplierTireProduct::SEASONS
    normalized_season = case season.to_s.downcase
    when /летн|літн|лето|літо|summer/
      'summer'
    when /зимн|зимов|зима|winter/
      'winter'
    when /всесезон|всесезон|all.season/
      'all_season'
    else
      season
    end
    
    Rails.logger.info "🔄 Нормализация сезона: '#{season}' → '#{normalized_season}'"
    
    @current_filters[:season] = normalized_season
    
    # Если у нас есть размер и сезон - сразу ищем и показываем результат
    if ready_for_recommendations?
      recommendations = get_tire_recommendations
      
      if recommendations.any?
        catalog_button_data = get_catalog_button_data if @current_filters[:size].present? && @current_filters[:season].present?
        
        return {
          message: "✅ #{localized_message('season_accepted', season: season)}\n\n#{format_recommendations(recommendations)}",
          filters_updated: @current_filters,
          recommendations: recommendations,
          catalog_button: catalog_button_data,
          action: 'show_recommendations_with_options'
        }
      else
        size_info = @current_filters[:size] ? @current_filters[:size][:full_size] : 'неизвестный'
        return {
          message: "✅ #{localized_message('season_accepted', season: season)}\n\n#{localized_message('no_results_suggest_changes', size: size_info, season: season)}",
          filters_updated: @current_filters,
          action: 'no_results',
          next_step: 'parameter_adjustment'
        }
      end
    else
      next_step = determine_next_step
      {
        message: "✅ #{localized_message('season_accepted', season: season)} #{get_next_question_for_context}",
        filters_updated: @current_filters,
        next_step: next_step
      }
    end
  end

  # Обработка запроса с моделью автомобиля
  def handle_car_model_request(parameters)
    car_model = parameters[:car_model]
    Rails.logger.info "🚗 Обработка запроса модели автомобиля: #{car_model}"
    
    # Сохраняем модель автомобиля в контексте
    @user_preferences[:car_model] = car_model
    
    # Формируем ответ с предложением перейти на поиск по автомобилю
    message = "🚗 Понял, вам нужны шины для **#{car_model}**.\n\n"
    message += "Для точного подбора размера шин по марке автомобиля я рекомендую воспользоваться нашим специальным поиском:\n\n"
    message += "🔍 **Поиск шин по автомобилю**\n"
    message += "Там вы сможете выбрать точную модель и год выпуска для подбора правильного размера.\n\n"
    message += "Или укажите размер шин вручную в формате: **205/55R16**, **225/60R17**"
    
    {
      message: message,
      filters_updated: @current_filters,
      preferences_updated: @user_preferences,
      action: 'show_car_search_button',
      car_search_query: car_model
    }
  end

  def handle_budget_constraint(parameters)
    budget_max = parameters[:budget_max]
    budget_min = parameters[:budget_min]
    
    @current_filters[:budget_max] = budget_max if budget_max
    @current_filters[:budget_min] = budget_min if budget_min
    
    # Проверяем, есть ли все обязательные данные для рекомендаций
    next_question = get_next_question_for_context
    next_step = ready_for_recommendations? ? 'recommendation_request' : determine_next_step
    
    {
      message: "💰 #{localized_message('budget_noted')} #{next_question}",
      filters_updated: @current_filters,
      next_step: next_step
    }
  end

  def handle_technical_question(parameters, available_products)
    {
      message: "🔧 Для детального технического консультирования рекомендую обратиться к нашим специалистам. А пока могу помочь с подбором шин по основным критериям.",
      next_step: 'general_question'
    }
  end

  def handle_general_question(parameters, available_products)
    {
      message: "👋 #{localized_message('welcome_message')}",
      next_step: 'size_request'
    }
  end

  # Обработка запроса на начало нового поиска
  def handle_new_search_request(parameters)
    reset_filters
    {
      message: "🔄 #{localized_message('new_search_started')}\n\n#{localized_message('welcome_message')}",
      filters_updated: @current_filters,
      action: 'new_search_started',
      next_step: 'size_request'
    }
  end

  # Обработка запроса на продолжение обсуждения текущих результатов
  def handle_continue_discussion(parameters)
    {
      message: "💬 #{localized_message('continue_discussion_ready')}",
      action: 'continue_discussion',
      next_step: 'discussion_mode'
    }
  end

  # Получение локализованного сообщения
  def localized_message(key, **interpolations)
    messages = {
      'ru' => {
        'size_question' => 'Какой размер шин вам нужен?',
        'season_question' => 'Какие шины нужны - зимние, летние или всесезонные?',
        'ready_to_recommend' => 'Отлично! У меня есть все необходимые данные. Ищу лучшие варианты для вас...',
        'budget_noted' => 'Учту ваш бюджет.',
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
        'recommendations_title' => 'Вот мои рекомендации для вас:',
        'recommendation_explanation_title' => 'Почему именно эти шины?',
        'continuation_options_title' => 'Что вы хотите сделать дальше?',
        'continue_discussion_option' => '💬 Обсудить эти варианты подробнее',
        'new_search_option' => '🔍 Начать новый поиск с другими параметрами',
        'continuation_prompt' => 'Просто напишите, что вас интересует!',
        'new_search_started' => 'Начинаем новый поиск! Все предыдущие параметры сброшены.',
        'continue_discussion_ready' => 'Отлично! Давайте обсудим найденные варианты шин. Что бы вы хотели узнать подробнее? Например, особенности конкретных моделей, сравнение характеристик или рекомендации по установке.',
        'need_more_info' => 'Для подбора оптимальных шин мне нужно знать:',
        'missing_size_param' => '📏 **Размер шин** - например: 205/55R16, 225/60R17',
        'missing_season_param' => '🌤️ **Сезон** - зимние, летние или всесезонные шины'
      },
      'uk' => {
        'size_question' => 'Який розмір шин вам потрібен?',
        'season_question' => 'Які шини потрібні - зимові, літні чи всесезонні?',
        'ready_to_recommend' => 'Відмінно! У мене є всі необхідні дані. Шукаю найкращі варіанти для вас...',
        'budget_noted' => 'Врахую ваш бюджет.',
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
        'recommendations_title' => 'Ось мої рекомендації для вас:',
        'recommendation_explanation_title' => 'Чому саме ці шини?',
        'continuation_options_title' => 'Що ви хочете зробити далі?',
        'continue_discussion_option' => '💬 Обговорити ці варіанти детальніше',
        'new_search_option' => '🔍 Почати новий пошук з іншими параметрами',
        'continuation_prompt' => 'Просто напишіть, що вас цікавить!',
        'new_search_started' => 'Починаємо новий пошук! Усі попередні параметри скинуто.',
        'continue_discussion_ready' => 'Відмінно! Давайте обговоримо знайдені варіанти шин. Що б ви хотіли дізнатися детальніше? Наприклад, особливості конкретних моделей, порівняння характеристик або рекомендації щодо встановлення.',
        'need_more_info' => 'Для підбору оптимальних шин мені потрібно знати:',
        'missing_size_param' => '📏 **Розмір шин** - наприклад: 205/55R16, 225/60R17',
        'missing_season_param' => '🌤️ **Сезон** - зимові, літні чи всесезонні шини'
      }
    }

    message_template = messages[@locale] ? messages[@locale][key] : messages['ru'][key]
    return key unless message_template
    
    # Заменяем интерполяции
    interpolations.each do |placeholder, value|
      message_template = message_template.gsub("%{#{placeholder}}", value.to_s)
    end
    
    message_template
  end

  # Получение следующего шага после указания размера
  def get_next_step_after_size
    if @current_filters[:season].blank?
      'season_request'
    else
      'recommendation_request'
    end
  end
  
  # Определение следующего шага в диалоге
  def determine_next_step
    if @current_filters[:size].blank?
      'size_request'
    elsif @current_filters[:season].blank?
      'season_request'
    else
      'recommendation_request'
    end
  end
end