# frozen_string_literal: true

# Service for AI-powered review moderation and analysis
# Uses AiRequestWrapper for resilient OpenAI calls with retry/circuit breaker
#
# Classification categories:
#   - positive: genuine positive review
#   - neutral: genuine neutral review
#   - negative: genuine negative review
#   - spam: promotional, repetitive, or irrelevant content
#   - inappropriate: profanity, hate speech, offensive content
#
# Decision flow:
#   - positive/neutral + high confidence -> auto-publish
#   - negative + high confidence -> publish + alert partner
#   - spam/inappropriate -> moderation queue (flagged)
#   - low confidence on any -> moderation queue (flagged)
class ReviewModerationService
  CACHE_TTL = 1.hour.to_i
  HIGH_CONFIDENCE_THRESHOLD = 0.8
  LOW_CONFIDENCE_THRESHOLD = 0.6

  # Classification categories
  CLASSIFICATIONS = %w[positive neutral negative spam inappropriate].freeze

  # Moderation result statuses
  MODERATION_STATUSES = {
    approved: 'approved',
    flagged: 'flagged',
    rejected: 'rejected',
    pending: 'pending'
  }.freeze

  # Sentiment categories
  SENTIMENTS = {
    positive: 'positive',
    neutral: 'neutral',
    negative: 'negative',
    mixed: 'mixed'
  }.freeze

  # Moderate a single review with AI classification
  # @param review [Review] the review to moderate
  # @return [Hash] moderation result with classification, sentiment, confidence
  def moderate(review)
    return cached_result(review) if cached?(review)

    # First pass: regex-based quick filters for obvious spam/profanity
    quick_result = quick_filter(review.comment)
    if quick_result[:decision_made]
      return save_result(review, quick_result)
    end

    # Second pass: AI-based moderation via AiRequestWrapper
    ai_result = ai_moderate(review)
    final_result = apply_decision_flow(ai_result)
    save_result(review, final_result)
  end

  # Analyze sentiment of a review
  # @param review [Review] the review to analyze
  # @return [Hash] sentiment analysis result
  def analyze_sentiment(review)
    cache_key = "review_sentiment:#{review.id}"
    cached = Rails.cache.read(cache_key)
    return cached if cached

    result = AiRequestWrapper.call(
      operation: 'review_sentiment_analysis',
      service_name: 'review_moderation',
      model: 'gpt-4.1-nano'
    ) do
      openai_service.chat_completion(
        build_sentiment_prompt(review),
        model: 'gpt-4.1-nano',
        max_tokens: 300,
        temperature: 0.1
      )
    end

    if result.success?
      parsed = parse_sentiment_response(result.data, review)
      Rails.cache.write(cache_key, parsed, expires_in: CACHE_TTL)
      parsed
    else
      fallback_sentiment(review)
    end
  end

  # Generate summary of multiple reviews for a service point
  # @param service_point [ServicePoint] the service point
  # @param limit [Integer] max reviews to analyze
  # @return [Hash] summary with pros/cons
  def summarize_reviews(service_point, limit: 50)
    cache_key = "reviews_summary:#{service_point.id}:#{service_point.reviews.maximum(:updated_at)}"
    cached = Rails.cache.read(cache_key)
    return cached if cached

    reviews = service_point.reviews.published.limit(limit).order(created_at: :desc)
    return nil if reviews.empty?

    result = AiRequestWrapper.call(
      operation: 'review_summary',
      service_name: 'review_moderation',
      model: 'gpt-4.1-nano'
    ) do
      openai_service.chat_completion(
        build_summary_prompt(reviews),
        model: 'gpt-4.1-nano',
        max_tokens: 500,
        temperature: 0.3
      )
    end

    if result.success?
      parsed = parse_summary_response(extract_content(result.data))
      Rails.cache.write(cache_key, parsed, expires_in: 6.hours)
      parsed
    else
      fallback_summary(reviews)
    end
  end

  # Batch moderate multiple reviews
  # @param reviews [Array<Review>] reviews to moderate
  # @return [Array<Hash>] moderation results
  def batch_moderate(reviews)
    reviews.map { |review| moderate(review) }
  end

  private

  def openai_service
    @openai_service ||= OpenaiService.new
  end

  # === Quick Regex Filters ===

  def quick_filter(text)
    return { decision_made: false } if text.blank?

    if spam_pattern?(text)
      return {
        decision_made: true,
        status: MODERATION_STATUSES[:rejected],
        classification: 'spam',
        reason: 'spam_detected',
        confidence: 0.95,
        sentiment: 'neutral'
      }
    end

    if profanity_detected?(text)
      return {
        decision_made: true,
        status: MODERATION_STATUSES[:flagged],
        classification: 'inappropriate',
        reason: 'profanity_detected',
        confidence: 0.9,
        sentiment: 'negative'
      }
    end

    if contact_info_detected?(text)
      return {
        decision_made: true,
        status: MODERATION_STATUSES[:flagged],
        classification: 'spam',
        reason: 'contact_info_detected',
        confidence: 0.85,
        sentiment: 'neutral'
      }
    end

    { decision_made: false }
  end

  def spam_pattern?(text)
    patterns = [
      /(.)\1{10,}/i,                                                       # Repeated characters
      /(купи|заказ|скидк|акци|бесплатн).*(http|www|\.com|\.ua)/i,         # Promotional links
      /\d{10,}/,                                                           # Long number sequences
      /(.{5,})\1{3,}/i                                                     # Repeated phrases
    ]
    patterns.any? { |p| text.match?(p) }
  end

  def profanity_detected?(text)
    # Russian and Ukrainian profanity patterns (obfuscated, handles char substitution)
    patterns = [
      /\b[хx][уy][йiї]/iu,
      /\b[бb][лl][яa][дd]/iu,
      /\b[пp][иi][зz][дd]/iu,
      /\b[сc][уy][кk][аa]/iu,
      /\b[еe][бb][аa][тtл]/iu,
      /\b[мm][уy][дd][аa][кk]/iu,
      /\b[дd][еe][рr][ьb][мm][оo]/iu,
      /\b[гg][оo][вв][нn][оo]/iu,
      /\b[жj][оo][пp][аa]/iu
    ]
    patterns.any? { |p| text.match?(p) }
  end

  def contact_info_detected?(text)
    patterns = [
      /\+?\d[\d\s\-\(\)]{9,}/,                                  # Phone numbers
      /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/,       # Email
      /(?:telegram|viber|whatsapp)[\s:]*@?\w+/i                  # Messengers
    ]
    patterns.any? { |p| text.match?(p) }
  end

  # === AI Moderation ===

  def ai_moderate(review)
    result = AiRequestWrapper.call(
      operation: 'review_ai_moderation',
      service_name: 'review_moderation',
      model: 'gpt-4.1-nano'
    ) do
      openai_service.chat_completion(
        build_moderation_prompt(review),
        model: 'gpt-4.1-nano',
        max_tokens: 400,
        temperature: 0.1
      )
    end

    if result.success?
      parse_moderation_response(extract_content(result.data))
    else
      # AI unavailable - return pending for manual review
      Rails.logger.warn "[ReviewModerationService] AI unavailable, falling back to pending: #{result.error}"
      fallback_moderation_result
    end
  end

  # Apply decision flow based on classification and confidence
  def apply_decision_flow(ai_result)
    classification = ai_result[:classification] || 'neutral'
    confidence = ai_result[:confidence] || 0.0
    sentiment = ai_result[:sentiment] || 'neutral'
    is_fake = ai_result[:is_fake] || false

    # Fake reviews always go to moderation queue
    if is_fake
      return ai_result.merge(
        status: MODERATION_STATUSES[:flagged],
        reason: 'suspected_fake_review'
      )
    end

    # Spam/inappropriate -> moderation queue
    if %w[spam inappropriate].include?(classification)
      return ai_result.merge(
        status: MODERATION_STATUSES[:flagged],
        reason: "#{classification}_detected"
      )
    end

    # Low confidence -> moderation queue
    if confidence < LOW_CONFIDENCE_THRESHOLD
      return ai_result.merge(
        status: MODERATION_STATUSES[:flagged],
        reason: 'low_confidence'
      )
    end

    # High confidence positive/neutral -> auto-publish
    if %w[positive neutral].include?(classification) && confidence >= HIGH_CONFIDENCE_THRESHOLD
      return ai_result.merge(
        status: MODERATION_STATUSES[:approved],
        reason: 'auto_approved_high_confidence'
      )
    end

    # High confidence negative -> publish + alert partner
    if classification == 'negative' && confidence >= HIGH_CONFIDENCE_THRESHOLD
      return ai_result.merge(
        status: MODERATION_STATUSES[:approved],
        reason: 'negative_approved_alert_partner',
        alert_partner: true
      )
    end

    # Medium confidence -> moderation queue
    ai_result.merge(
      status: MODERATION_STATUSES[:flagged],
      reason: 'medium_confidence'
    )
  end

  # === Prompt Builders ===

  def build_moderation_prompt(review)
    <<~PROMPT
      You are a review moderation system for a tire service marketplace. Analyze the following review and provide a JSON response.

      Review (rating: #{review.rating}/5):
      #{review.comment}

      Classify the review:
      1. classification: one of [positive, neutral, negative, spam, inappropriate]
      2. sentiment: one of [positive, neutral, negative, mixed]
      3. confidence: float between 0.0 and 1.0
      4. is_fake: boolean - does this look like a fake/planted review?
      5. fake_indicators: array of reasons if is_fake is true
      6. topics: array of topics mentioned (e.g., "service_speed", "price", "quality", "staff")
      7. summary: brief 1-sentence summary of the review

      Rules:
      - Spam: promotional content, repeated text, irrelevant content, contact info
      - Inappropriate: profanity, hate speech, personal attacks, offensive language
      - Fake indicators: overly generic praise, suspicious timing mentions, marketing language
      - Constructive negative reviews should be classified as "negative" (not inappropriate)
      - Consider both Russian and Ukrainian language reviews

      Respond ONLY with valid JSON:
      {"classification": "...", "sentiment": "...", "confidence": 0.X, "is_fake": false, "fake_indicators": [], "topics": [], "summary": "..."}
    PROMPT
  end

  def build_sentiment_prompt(review)
    <<~PROMPT
      Analyze the sentiment of this tire service review (rating: #{review.rating}/5):
      #{review.comment}

      Respond ONLY with valid JSON:
      {"sentiment": "positive/neutral/negative/mixed", "pros": ["..."], "cons": ["..."], "topics": ["..."]}
    PROMPT
  end

  def build_summary_prompt(reviews)
    reviews_text = reviews.map.with_index do |r, i|
      "#{i + 1}. Rating: #{r.rating}/5 - #{r.comment.to_s.truncate(200)}"
    end.join("\n")

    <<~PROMPT
      Analyze these tire service reviews and create a summary in Russian:

      #{reviews_text}

      Respond ONLY with valid JSON:
      {"overall": "...", "pros": ["..."], "cons": ["..."], "satisfaction_level": "high/medium/low"}
    PROMPT
  end

  # === Response Parsers ===

  def extract_content(data)
    return '' unless data.is_a?(Hash)

    data.dig('choices', 0, 'message', 'content') || ''
  end

  def parse_moderation_response(content)
    json = parse_json_from_content(content)
    {
      classification: validate_classification(json['classification']),
      sentiment: validate_sentiment(json['sentiment']),
      confidence: (json['confidence']&.to_f || 0.5).clamp(0.0, 1.0),
      is_fake: json['is_fake'] == true,
      fake_indicators: Array(json['fake_indicators']),
      topics: Array(json['topics']),
      summary: json['summary'].to_s.truncate(500)
    }
  rescue StandardError => e
    Rails.logger.error("[ReviewModerationService] Failed to parse moderation response: #{e.message}")
    fallback_moderation_result
  end

  def parse_sentiment_response(data, review)
    content = extract_content(data)
    json = parse_json_from_content(content)
    {
      review_id: review.id,
      sentiment: validate_sentiment(json['sentiment']),
      pros: Array(json['pros']),
      cons: Array(json['cons']),
      topics: Array(json['topics']),
      analyzed_at: Time.current
    }
  rescue StandardError => e
    Rails.logger.error("[ReviewModerationService] Failed to parse sentiment: #{e.message}")
    fallback_sentiment(review)
  end

  def parse_summary_response(content)
    json = parse_json_from_content(content)
    {
      overall: json['overall'].to_s,
      pros: Array(json['pros']),
      cons: Array(json['cons']),
      satisfaction_level: json['satisfaction_level'] || 'medium',
      generated_at: Time.current
    }
  rescue StandardError => e
    Rails.logger.error("[ReviewModerationService] Failed to parse summary: #{e.message}")
    { overall: '', pros: [], cons: [], satisfaction_level: 'medium' }
  end

  def parse_json_from_content(content)
    return {} if content.blank?

    # Strip markdown code blocks if present
    cleaned = content.strip
    cleaned = cleaned.gsub(/\A```json\n?/, '').gsub(/\n?```\z/, '') if cleaned.start_with?('```')
    JSON.parse(cleaned)
  rescue JSON::ParserError
    {}
  end

  def validate_classification(value)
    CLASSIFICATIONS.include?(value.to_s) ? value.to_s : 'neutral'
  end

  def validate_sentiment(value)
    SENTIMENTS.values.include?(value.to_s) ? value.to_s : 'neutral'
  end

  # === Fallbacks ===

  def fallback_moderation_result
    {
      classification: 'neutral',
      sentiment: 'neutral',
      confidence: 0.0,
      is_fake: false,
      fake_indicators: [],
      topics: [],
      summary: '',
      status: MODERATION_STATUSES[:flagged],
      reason: 'ai_unavailable'
    }
  end

  def fallback_sentiment(review)
    # Simple heuristic based on rating
    sentiment = case review.rating
                when 4, 5 then 'positive'
                when 3 then 'neutral'
                when 1, 2 then 'negative'
                else 'neutral'
                end

    {
      review_id: review.id,
      sentiment: sentiment,
      pros: [],
      cons: [],
      topics: [],
      analyzed_at: Time.current
    }
  end

  def fallback_summary(reviews)
    avg_rating = reviews.average(:rating).to_f.round(1)
    satisfaction = if avg_rating >= 4.0
                     'high'
                   elsif avg_rating >= 3.0
                     'medium'
                   else
                     'low'
                   end

    {
      overall: "Average rating: #{avg_rating}/5 based on #{reviews.count} reviews",
      pros: [],
      cons: [],
      satisfaction_level: satisfaction,
      generated_at: Time.current
    }
  end

  # === Cache ===

  def cached?(review)
    Rails.cache.exist?("review_moderation:#{review.id}")
  end

  def cached_result(review)
    Rails.cache.read("review_moderation:#{review.id}")
  end

  # === Persistence ===

  def save_result(review, result)
    # Update review record with AI moderation data
    update_attrs = {
      moderation_status: result[:status],
      moderation_reason: result[:reason],
      moderation_confidence: result[:confidence],
      moderated_at: Time.current,
      ai_sentiment: result[:sentiment],
      ai_classification: result[:classification],
      ai_is_fake: result[:is_fake] || false,
      ai_metadata: {
        topics: result[:topics],
        summary: result[:summary],
        fake_indicators: result[:fake_indicators]
      }.compact
    }

    # Auto-publish approved reviews
    if result[:status] == MODERATION_STATUSES[:approved]
      update_attrs[:status] = 'published'
    end

    review.skip_notifications = true
    review.update(update_attrs)

    # Alert partner for negative reviews
    if result[:alert_partner]
      notify_partner_about_negative_review(review)
    end

    # Cache the result
    cache_key = "review_moderation:#{review.id}"
    Rails.cache.write(cache_key, result, expires_in: CACHE_TTL)

    result
  end

  def notify_partner_about_negative_review(review)
    partner = review.service_point&.partner
    return unless partner&.user

    if defined?(BookingNotificationJob)
      BookingNotificationJob.perform_later(
        review.id,
        'negative_review_alert',
        partner.user.email
      )
    end

    Rails.logger.info "[ReviewModerationService] Negative review alert sent for review #{review.id}"
  rescue StandardError => e
    Rails.logger.warn "[ReviewModerationService] Failed to notify partner: #{e.message}"
  end
end
