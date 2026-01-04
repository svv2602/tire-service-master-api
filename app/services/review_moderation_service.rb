# frozen_string_literal: true

# Service for AI-powered review moderation and analysis
# Uses GPT-3.5 for cost-efficiency with cascade to GPT-4 for complex cases
class ReviewModerationService
  CACHE_TTL = 1.hour.to_i
  CONFIDENCE_THRESHOLD = 0.8

  # Moderation result statuses
  MODERATION_STATUSES = {
    approved: 'approved',           # Review is clean and approved
    flagged: 'flagged',             # Needs manual review
    rejected: 'rejected',           # Auto-rejected (spam, profanity)
    pending: 'pending'              # Not yet moderated
  }.freeze

  # Sentiment categories
  SENTIMENTS = {
    positive: 'positive',
    neutral: 'neutral',
    negative: 'negative',
    mixed: 'mixed'
  }.freeze

  def initialize
    @openai = OpenaiService.new
  end

  # Moderate a single review
  # @param review [Review] the review to moderate
  # @return [Hash] moderation result
  def moderate(review)
    return cached_result(review) if cached?(review)

    # First pass: regex-based quick filters
    quick_result = quick_filter(review.comment)
    return save_result(review, quick_result) if quick_result[:decision_made]

    # Second pass: GPT-3.5 for standard cases
    ai_result = ai_moderate(review)
    save_result(review, ai_result)
  end

  # Analyze sentiment of a review
  # @param review [Review] the review to analyze
  # @return [Hash] sentiment analysis result
  def analyze_sentiment(review)
    cache_key = "review_sentiment:#{review.id}"
    cached = Rails.cache.read(cache_key)
    return cached if cached

    result = @openai.chat(
      messages: build_sentiment_messages(review),
      model: 'gpt-3.5-turbo'
    )

    parsed = parse_sentiment_response(result['content'], review)
    Rails.cache.write(cache_key, parsed, expires_in: CACHE_TTL)
    parsed
  end

  # Generate summary of multiple reviews for a service point
  # @param service_point [ServicePoint] the service point
  # @param limit [Integer] max reviews to analyze
  # @return [Hash] summary with pros/cons
  def summarize_reviews(service_point, limit: 50)
    cache_key = "reviews_summary:#{service_point.id}:#{service_point.reviews.maximum(:updated_at)}"
    cached = Rails.cache.read(cache_key)
    return cached if cached

    reviews = service_point.reviews.approved.limit(limit).order(created_at: :desc)
    return nil if reviews.empty?

    result = @openai.chat(
      messages: build_summary_messages(reviews),
      model: 'gpt-3.5-turbo'
    )

    parsed = parse_summary_response(result['content'])
    Rails.cache.write(cache_key, parsed, expires_in: 6.hours)
    parsed
  end

  # Batch moderate multiple reviews
  # @param reviews [Array<Review>] reviews to moderate
  # @return [Array<Hash>] moderation results
  def batch_moderate(reviews)
    reviews.map { |review| moderate(review) }
  end

  # Generate auto-response for a review
  # @param review [Review] the review to respond to
  # @return [Hash] suggested response
  def generate_response(review)
    cache_key = "review_response:#{review.id}"
    cached = Rails.cache.read(cache_key)
    return cached if cached

    sentiment = analyze_sentiment(review)

    result = @openai.chat(
      messages: build_response_messages(review, sentiment),
      model: 'gpt-3.5-turbo'
    )

    response = {
      suggested_response: result['content'],
      sentiment: sentiment[:sentiment],
      tone: sentiment[:sentiment] == 'negative' ? 'apologetic' : 'appreciative',
      generated_at: Time.current
    }

    Rails.cache.write(cache_key, response, expires_in: CACHE_TTL)
    response
  end

  private

  # Quick regex-based filters for obvious cases
  def quick_filter(text)
    return { decision_made: false } if text.blank?

    # Check for spam patterns
    if spam_pattern?(text)
      return {
        decision_made: true,
        status: MODERATION_STATUSES[:rejected],
        reason: 'spam_detected',
        confidence: 0.95
      }
    end

    # Check for profanity
    if profanity_detected?(text)
      return {
        decision_made: true,
        status: MODERATION_STATUSES[:flagged],
        reason: 'profanity_detected',
        confidence: 0.9
      }
    end

    # Check for contact info (phone, email)
    if contact_info_detected?(text)
      return {
        decision_made: true,
        status: MODERATION_STATUSES[:flagged],
        reason: 'contact_info_detected',
        confidence: 0.85
      }
    end

    { decision_made: false }
  end

  def spam_pattern?(text)
    patterns = [
      /(.)\1{10,}/i,                          # Repeated characters
      /(купи|заказ|скидк|акци|бесплатн).*(http|www|\.com|\.ua)/i,  # Promotional links
      /\d{10,}/,                              # Long number sequences
      /(.{5,})\1{3,}/i                        # Repeated phrases
    ]
    patterns.any? { |p| text.match?(p) }
  end

  def profanity_detected?(text)
    # Basic profanity patterns (obfuscated)
    patterns = [
      /\b[хx][уy][йiї]/iu,
      /\b[бb][лl][яa][дd]/iu,
      /\b[пp][иi][зz][дd]/iu,
      /\b[сc][уy][кk]/iu,
      /\b[еe][бb][аa]/iu
    ]
    patterns.any? { |p| text.match?(p) }
  end

  def contact_info_detected?(text)
    patterns = [
      /\+?\d[\d\s\-\(\)]{9,}/,               # Phone numbers
      /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/, # Email
      /(?:telegram|viber|whatsapp)[\s:]*@?\w+/i  # Messengers
    ]
    patterns.any? { |p| text.match?(p) }
  end

  def ai_moderate(review)
    result = @openai.chat(
      messages: build_moderation_messages(review),
      model: 'gpt-3.5-turbo'
    )

    parse_moderation_response(result['content'])
  rescue StandardError => e
    Rails.logger.error("AI moderation failed: #{e.message}")
    {
      status: MODERATION_STATUSES[:pending],
      reason: 'ai_error',
      confidence: 0,
      error: e.message
    }
  end

  def build_moderation_messages(review)
    [
      {
        role: 'system',
        content: <<~PROMPT
          Ты модератор отзывов для сервиса шиномонтажа. Твоя задача - проанализировать отзыв и определить:
          1. Подходит ли он для публикации (approved/flagged/rejected)
          2. Причину решения
          3. Уровень уверенности (0-1)

          Отклоняй отзывы со спамом, рекламой, оскорблениями, контактной информацией.
          Помечай для ручной проверки подозрительные отзывы.
          Одобряй конструктивные отзывы, даже негативные.

          Отвечай в формате JSON:
          {"status": "approved/flagged/rejected", "reason": "причина", "confidence": 0.X}
        PROMPT
      },
      {
        role: 'user',
        content: <<~CONTENT
          Отзыв (рейтинг: #{review.rating}/5):
          #{review.comment}
        CONTENT
      }
    ]
  end

  def build_sentiment_messages(review)
    [
      {
        role: 'system',
        content: <<~PROMPT
          Проанализируй отзыв о шиномонтаже и определи:
          1. Общую тональность: positive/neutral/negative/mixed
          2. Ключевые плюсы (если есть)
          3. Ключевые минусы (если есть)
          4. Основные темы

          Отвечай в формате JSON:
          {"sentiment": "...", "pros": [...], "cons": [...], "topics": [...]}
        PROMPT
      },
      {
        role: 'user',
        content: "Отзыв (рейтинг: #{review.rating}/5):\n#{review.comment}"
      }
    ]
  end

  def build_summary_messages(reviews)
    reviews_text = reviews.map.with_index do |r, i|
      "#{i + 1}. Рейтинг: #{r.rating}/5 - #{r.comment.truncate(200)}"
    end.join("\n")

    [
      {
        role: 'system',
        content: <<~PROMPT
          Проанализируй отзывы о шиномонтаже и создай краткое резюме:
          1. Общее впечатление клиентов
          2. Топ-3 плюса сервиса
          3. Топ-3 минуса или области для улучшения
          4. Средний уровень удовлетворенности

          Отвечай на русском в формате JSON:
          {"overall": "...", "pros": [...], "cons": [...], "satisfaction_level": "high/medium/low"}
        PROMPT
      },
      {
        role: 'user',
        content: "Отзывы:\n#{reviews_text}"
      }
    ]
  end

  def build_response_messages(review, sentiment)
    [
      {
        role: 'system',
        content: <<~PROMPT
          Ты менеджер шиномонтажа. Сгенерируй вежливый ответ на отзыв клиента.

          Правила:
          - Для положительных отзывов: благодарность, приглашение вернуться
          - Для негативных: извинения, обещание улучшить, предложение связаться
          - Для нейтральных: благодарность за обратную связь
          - Не больше 2-3 предложений
          - Профессиональный тон
          - На русском языке
        PROMPT
      },
      {
        role: 'user',
        content: <<~CONTENT
          Тональность: #{sentiment[:sentiment]}
          Рейтинг: #{review.rating}/5
          Отзыв: #{review.comment}
        CONTENT
      }
    ]
  end

  def parse_moderation_response(content)
    json = JSON.parse(content)
    {
      status: json['status'] || MODERATION_STATUSES[:pending],
      reason: json['reason'] || 'unknown',
      confidence: json['confidence']&.to_f || 0.5
    }
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse moderation response: #{e.message}")
    { status: MODERATION_STATUSES[:flagged], reason: 'parse_error', confidence: 0.5 }
  end

  def parse_sentiment_response(content, review)
    json = JSON.parse(content)
    {
      review_id: review.id,
      sentiment: json['sentiment'] || SENTIMENTS[:neutral],
      pros: json['pros'] || [],
      cons: json['cons'] || [],
      topics: json['topics'] || [],
      analyzed_at: Time.current
    }
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse sentiment response: #{e.message}")
    { review_id: review.id, sentiment: SENTIMENTS[:neutral], pros: [], cons: [], topics: [] }
  end

  def parse_summary_response(content)
    json = JSON.parse(content)
    {
      overall: json['overall'] || '',
      pros: json['pros'] || [],
      cons: json['cons'] || [],
      satisfaction_level: json['satisfaction_level'] || 'medium',
      generated_at: Time.current
    }
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse summary response: #{e.message}")
    { overall: '', pros: [], cons: [], satisfaction_level: 'medium' }
  end

  def cached?(review)
    Rails.cache.exist?("review_moderation:#{review.id}")
  end

  def cached_result(review)
    Rails.cache.read("review_moderation:#{review.id}")
  end

  def save_result(review, result)
    # Update review record if it has moderation fields
    if review.respond_to?(:moderation_status)
      review.update(
        moderation_status: result[:status],
        moderation_reason: result[:reason],
        moderation_confidence: result[:confidence],
        moderated_at: Time.current
      )
    end

    # Cache the result
    cache_key = "review_moderation:#{review.id}"
    Rails.cache.write(cache_key, result, expires_in: CACHE_TTL)

    result
  end
end
