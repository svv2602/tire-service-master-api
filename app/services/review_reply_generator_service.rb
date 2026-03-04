# frozen_string_literal: true

# Service for AI-powered review reply generation
# Generates personalized reply suggestions based on review content, sentiment, and rating
#
# Uses AiRequestWrapper for resilient OpenAI calls.
# Partner sees the suggested reply and can edit before sending.
#
# Reply strategies:
#   - positive: thank you with personalization, invite to return
#   - negative: apology + specific solution offer based on mentioned issues
#   - neutral: thanks for feedback + invite to return
#   - spam/inappropriate: no reply generated
#
# Usage:
#   service = ReviewReplyGeneratorService.new
#   result = service.generate(review)
#   # => { suggested_reply: "...", tone: "appreciative", sentiment: "positive", generated_at: ... }
class ReviewReplyGeneratorService
  CACHE_TTL = 2.hours.to_i

  # Generate a reply suggestion for a review
  # @param review [Review] the review to generate a reply for
  # @param options [Hash] additional options
  # @option options [String] :language ('ru') reply language ('ru' or 'uk')
  # @option options [String] :partner_name optional partner business name
  # @return [Hash] reply suggestion with metadata
  def generate(review, options = {})
    return no_reply_needed if skip_reply?(review)

    cache_key = "review_reply:#{review.id}:#{options.hash}"
    cached = Rails.cache.read(cache_key)
    return cached if cached

    language = options[:language] || 'ru'
    partner_name = options[:partner_name] || review.service_point&.name || ''

    # Determine sentiment from AI metadata or rating
    sentiment = determine_sentiment(review)

    result = AiRequestWrapper.call(
      operation: 'review_reply_generation',
      service_name: 'review_reply_generator',
      model: 'gpt-4.1-nano'
    ) do
      openai_service.chat_completion(
        build_reply_prompt(review, sentiment, language, partner_name),
        model: 'gpt-4.1-nano',
        max_tokens: 300,
        temperature: 0.7
      )
    end

    response = if result.success?
                 content = extract_content(result.data)
                 parse_reply_response(content, sentiment)
               else
                 fallback_reply(review, sentiment, language)
               end

    Rails.cache.write(cache_key, response, expires_in: CACHE_TTL)
    response
  end

  # Generate replies for multiple reviews (batch)
  # @param reviews [Array<Review>] reviews to generate replies for
  # @param options [Hash] options passed to generate
  # @return [Array<Hash>] array of reply results keyed by review_id
  def batch_generate(reviews, options = {})
    reviews.map do |review|
      { review_id: review.id, **generate(review, options) }
    end
  end

  private

  def openai_service
    @openai_service ||= OpenaiService.new
  end

  # Determine if a reply should be skipped
  def skip_reply?(review)
    return true if review.comment.blank?
    return true if review.ai_classification.in?(%w[spam inappropriate])
    return true if review.moderation_status == 'rejected'

    false
  end

  def no_reply_needed
    {
      suggested_reply: nil,
      tone: nil,
      sentiment: nil,
      skipped: true,
      reason: 'reply_not_applicable',
      generated_at: Time.current
    }
  end

  # Determine sentiment from AI metadata or fallback to rating
  def determine_sentiment(review)
    # Use AI sentiment if available
    return review.ai_sentiment if review.respond_to?(:ai_sentiment) && review.ai_sentiment.present?

    # Fallback to rating-based heuristic
    case review.rating
    when 4, 5 then 'positive'
    when 3 then 'neutral'
    when 1, 2 then 'negative'
    else 'neutral'
    end
  end

  def build_reply_prompt(review, sentiment, language, partner_name)
    lang_instruction = if language == 'uk'
                         'Write the reply in Ukrainian language.'
                       else
                         'Write the reply in Russian language.'
                       end

    service_point_context = partner_name.present? ? " at \"#{partner_name}\"" : ''

    <<~PROMPT
      You are a professional customer service manager for a tire service#{service_point_context}.
      Generate a reply to a customer review.

      Review details:
      - Rating: #{review.rating}/5
      - Sentiment: #{sentiment}
      - Text: #{review.comment}

      Reply rules based on sentiment:
      #{reply_rules_for_sentiment(sentiment)}

      General rules:
      - Maximum 2-3 sentences
      - Professional and warm tone
      - #{lang_instruction}
      - Do NOT use emojis
      - Do NOT include generic platitudes without specifics
      - Reference specific details from the review when possible
      - Do NOT start with "Dear customer" or similar formal greetings

      Respond ONLY with valid JSON:
      {"reply": "the reply text", "tone": "appreciative/apologetic/neutral"}
    PROMPT
  end

  def reply_rules_for_sentiment(sentiment)
    case sentiment
    when 'positive'
      <<~RULES
        - Thank the customer for the positive feedback
        - Reference specific things they praised
        - Invite them to visit again
        - Tone: appreciative, warm
      RULES
    when 'negative'
      <<~RULES
        - Apologize sincerely for the negative experience
        - Acknowledge the specific issues mentioned
        - Offer a concrete solution or invite to contact management
        - Tone: apologetic, solution-oriented
      RULES
    when 'mixed'
      <<~RULES
        - Thank for the detailed feedback
        - Acknowledge both positive and negative points
        - Promise improvement on negative aspects
        - Tone: balanced, constructive
      RULES
    else # neutral
      <<~RULES
        - Thank for taking the time to leave a review
        - Acknowledge any specific feedback mentioned
        - Invite them to visit again
        - Tone: friendly, inviting
      RULES
    end
  end

  def extract_content(data)
    return '' unless data.is_a?(Hash)

    data.dig('choices', 0, 'message', 'content') || ''
  end

  def parse_reply_response(content, sentiment)
    return fallback_reply_from_sentiment(sentiment) if content.blank?

    # Try to parse JSON first
    json = parse_json(content)

    if json['reply'].present?
      {
        suggested_reply: json['reply'].strip,
        tone: json['tone'] || tone_for_sentiment(sentiment),
        sentiment: sentiment,
        generated_at: Time.current
      }
    else
      # If JSON parsing fails, use raw content as reply
      {
        suggested_reply: content.strip.truncate(500),
        tone: tone_for_sentiment(sentiment),
        sentiment: sentiment,
        generated_at: Time.current
      }
    end
  end

  def parse_json(content)
    cleaned = content.strip
    cleaned = cleaned.gsub(/\A```json\n?/, '').gsub(/\n?```\z/, '') if cleaned.start_with?('```')
    JSON.parse(cleaned)
  rescue JSON::ParserError
    {}
  end

  def tone_for_sentiment(sentiment)
    case sentiment
    when 'positive' then 'appreciative'
    when 'negative' then 'apologetic'
    else 'neutral'
    end
  end

  # === Fallback Replies (when AI is unavailable) ===

  def fallback_reply(review, sentiment, language)
    template = find_matching_template(review, sentiment)

    if template
      template.increment_usage!
      reply_text = template.render_with_variables(
        'client_name' => review.client&.user&.first_name || '',
        'service_point' => review.service_point&.name || '',
        'rating' => review.rating.to_s
      )
    else
      reply_text = default_fallback_reply(sentiment, language)
    end

    {
      suggested_reply: reply_text,
      tone: tone_for_sentiment(sentiment),
      sentiment: sentiment,
      from_template: template.present?,
      generated_at: Time.current
    }
  end

  def fallback_reply_from_sentiment(sentiment)
    {
      suggested_reply: default_fallback_reply(sentiment, 'ru'),
      tone: tone_for_sentiment(sentiment),
      sentiment: sentiment,
      generated_at: Time.current
    }
  end

  def find_matching_template(review, sentiment)
    partner_id = review.service_point&.partner_id
    category = template_category_for_sentiment(sentiment)

    ReviewReplyTemplate
      .available_for_partner(partner_id)
      .by_category(category)
      .first
  rescue StandardError
    nil
  end

  def template_category_for_sentiment(sentiment)
    case sentiment
    when 'positive' then 'positive'
    when 'negative' then 'apology'
    else 'general'
    end
  end

  def default_fallback_reply(sentiment, language)
    if language == 'uk'
      case sentiment
      when 'positive'
        'Дякуємо за ваш відгук! Ми раді, що вам сподобався наш сервіс. Будемо раді бачити вас знову!'
      when 'negative'
        'Дякуємо за ваш відгук. Нам шкода, що ваш досвід був негативним. Ми працюємо над покращенням якості обслуговування.'
      else
        'Дякуємо, що залишили відгук. Ваша думка допомагає нам ставати кращими. Будемо раді бачити вас знову!'
      end
    else
      case sentiment
      when 'positive'
        'Спасибо за ваш отзыв! Мы рады, что вам понравился наш сервис. Будем рады видеть вас снова!'
      when 'negative'
        'Спасибо за ваш отзыв. Нам жаль, что ваш опыт был негативным. Мы работаем над улучшением качества обслуживания.'
      else
        'Спасибо, что оставили отзыв. Ваше мнение помогает нам становиться лучше. Будем рады видеть вас снова!'
      end
    end
  end
end
