# frozen_string_literal: true

class CarSearchLlmService
  CAR_SEARCH_PROMPT = <<~PROMPT
    Ты - эксперт по автомобилям. Твоя задача - извлечь из пользовательского запроса информацию об автомобиле и сопоставить её с базой данных.

    ОСОБЕННОСТИ МОДИФИКАЦИЙ ДВИГАТЕЛЕЙ:
    - Цифры после модели (200d, 320i, 450d, AMG 63s) - это модификации двигателя, НЕ отдельные модели
    - Все модификации одной модели используют одинаковые размеры шин
    - Примеры:
      * Mercedes GLE 450d → модель "GLE-Class"
      * BMW 320i → модель "3 Series"
      * Audi A4 2.0T → модель "A4"

    ПРАВИЛА СОПОСТАВЛЕНИЯ МОДЕЛЕЙ:
    Mercedes:
    - GLE (любые модификации: 200d, 300d, 450d, AMG 63s) → "GLE-Class"
    - GLE Coupe (любые модификации) → "GLE-Class Coupe"
    - GLC (любые модификации) → "GLC-Class"
    - C-Class (C200, C220, C300, AMG) → "C-Class"
    - E-Class (E200, E220, E300, AMG) → "E-Class"
    - S-Class (S400, S500, S600, AMG) → "S-Class"
    - A-Class (A180, A200, A250, AMG) → "A-Class"

    BMW:
    - 3 Series (318i, 320i, 325i, 330i, M3) → "3 Series"
    - 5 Series (520i, 525i, 530i, 535i, M5) → "5 Series"
    - X3 (любые модификации) → "X3"
    - X5 (любые модификации) → "X5"

    Audi:
    - A3 (любые модификации) → "A3"
    - A4 (любые модификации) → "A4"
    - Q5 (любые модификации) → "Q5"

    ЯЗЫКОВЫЕ ОСОБЕННОСТИ:
    - "жле", "гле" → GLE
    - "цэ класс", "с класс" → C-Class
    - "е класс" → E-Class
    - "бмв тройка" → 3 Series

    Отвечай СТРОГО в JSON формате:
    {
      "brand": "Mercedes",
      "model": "GLE-Class",
      "engine_modification": "450d",
      "year": 2023,
      "confidence": 0.95,
      "reasoning": "Запрос содержит Mercedes GLE 450d - это модель GLE-Class с дизельным двигателем 450d"
    }

    ПРАВИЛА:
    - brand - стандартное английское название (BMW, Mercedes, Audi)
    - model - точное название модели из базы данных
    - engine_modification - модификация двигателя (если есть)
    - confidence - уверенность от 0 до 1
    - reasoning - объяснение логики сопоставления
    - Если не уверен - укажи confidence < 0.5

    Запрос пользователя:
  PROMPT

  def initialize
    @openai_service = OpenaiService.new
  end

  def parse_car_query(query)
    return fallback_response unless @openai_service&.send(:llm_enabled?)

    begin
      response = @openai_service.chat_completion("#{CAR_SEARCH_PROMPT}#{query}", {
        model: 'gpt-4.1-mini',
        max_tokens: 300,
        temperature: 0.1
      })

      content = response&.dig("choices", 0, "message", "content")
      return fallback_response unless content.present?

      # Очищаем markdown обертку если есть
      json_content = clean_json_content(content)
      
      # Парсим JSON ответ
      result = JSON.parse(json_content)
      
      # Валидируем результат
      validated_result = validate_llm_result(result)
      
      Rails.logger.info "🚗 CarSearchLlmService: успешно обработан запрос '#{query}' -> #{validated_result}"
      validated_result
      
    rescue JSON::ParserError => e
      Rails.logger.error "🚗 CarSearchLlmService JSON parse error: #{e.message}, content: #{content}"
      fallback_response
    rescue => e
      Rails.logger.error "🚗 CarSearchLlmService error: #{e.message}"
      fallback_response
    end
  end

  # Проверяет, нужен ли LLM для данного запроса
  def needs_llm?(query)
    return false if query.blank?
    
    query_lower = query.downcase.strip
    
    # LLM нужен если:
    # 1. Есть модификации двигателя (цифры + буквы)
    has_engine_mod = query_lower.match?(/\b\d{3,4}[a-zа-я]*\b/i)
    
    # 2. Есть сложные конструкции
    has_complex_phrases = query_lower.match?(/(класс|series|amg|coupe|седан|кроссовер)/i)
    
    # 3. Смешанная кириллица/латиница
    has_mixed_script = query.match?(/[а-яё]/i) && query.match?(/[a-z]/i)
    
    # 4. Фонетические аналоги латинских названий на кириллице
    has_phonetic_models = query_lower.match?(/\b(жле|гле|же|кс|эс|эм|бээм|цээ|бмв)\b/i)
    
    result = has_engine_mod || has_complex_phrases || has_mixed_script || has_phonetic_models
    
    Rails.logger.info "🚗 CarSearchLlmService: needs_llm? '#{query}' -> #{result} (engine_mod: #{has_engine_mod}, complex: #{has_complex_phrases}, mixed: #{has_mixed_script}, phonetic: #{has_phonetic_models})"
    result
  end

  private

  def clean_json_content(content)
    json_content = content.strip
    if json_content.start_with?('```json') && json_content.end_with?('```')
      json_content = json_content.gsub(/\A```json\n?/, '').gsub(/\n?```\z/, '')
    elsif json_content.start_with?('```') && json_content.end_with?('```')
      json_content = json_content.gsub(/\A```\n?/, '').gsub(/\n?```\z/, '')
    end
    json_content
  end

  def validate_llm_result(result)
    validated = {
      brand: result['brand']&.to_s&.strip,
      model: result['model']&.to_s&.strip,
      engine_modification: result['engine_modification']&.to_s&.strip,
      year: result['year']&.to_i,
      confidence: [result['confidence']&.to_f || 0.0, 1.0].min,
      reasoning: result['reasoning']&.to_s&.strip
    }

    # Убираем пустые значения
    validated.reject { |_, v| v.blank? || (v.is_a?(Numeric) && v.zero?) }
  end

  def fallback_response
    {
      brand: nil,
      model: nil,
      confidence: 0.0,
      reasoning: "LLM недоступен или произошла ошибка"
    }
  end
end