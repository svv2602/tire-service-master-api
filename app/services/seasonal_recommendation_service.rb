# frozen_string_literal: true

# Service for seasonal tire recommendations
# Analyzes user history, weather patterns, and tire conditions
class SeasonalRecommendationService
  CACHE_TTL = 24.hours.to_i

  # Temperature thresholds for tire recommendations (Celsius)
  WINTER_THRESHOLD = 7
  SUMMER_THRESHOLD = 15

  # Season types
  SEASONS = {
    winter: 'winter',
    summer: 'summer',
    all_season: 'all_season'
  }.freeze

  def initialize
    @openai = OpenaiService.new
  end

  # Get tire change recommendation for a user
  # @param client [Client] the client to generate recommendation for
  # @return [Hash] recommendation with reasoning
  def recommend_tire_change(client)
    cache_key = "tire_recommendation:#{client.id}:#{Date.current}"
    cached = Rails.cache.read(cache_key)
    return cached if cached

    # Gather context data
    context = build_recommendation_context(client)

    # Check if recommendation is needed
    unless should_recommend?(context)
      result = { needs_change: false, reason: 'no_change_needed' }
      Rails.cache.write(cache_key, result, expires_in: CACHE_TTL)
      return result
    end

    # Generate AI recommendation
    recommendation = generate_recommendation(context)
    Rails.cache.write(cache_key, recommendation, expires_in: CACHE_TTL)
    recommendation
  end

  # Get tire recommendations for a specific vehicle
  # @param vehicle_info [Hash] vehicle details (brand, model, year)
  # @param season [String] target season
  # @return [Hash] tire recommendations
  def recommend_tires_for_vehicle(vehicle_info, season: nil)
    target_season = season || current_recommended_season
    cache_key = "vehicle_tires:#{vehicle_info.values.join(':')}:#{target_season}"

    cached = Rails.cache.read(cache_key)
    return cached if cached

    result = @openai.chat(
      messages: build_vehicle_recommendation_messages(vehicle_info, target_season),
      model: 'gpt-4.1-nano'
    )

    parsed = parse_tire_recommendations(result['content'])
    Rails.cache.write(cache_key, parsed, expires_in: 7.days)
    parsed
  end

  # Determine the current recommended season for tires
  # @return [String] winter/summer/all_season
  def current_recommended_season
    month = Date.current.month

    case month
    when 11, 12, 1, 2, 3 # November - March
      SEASONS[:winter]
    when 5, 6, 7, 8, 9 # May - September
      SEASONS[:summer]
    else # April, October - transition months
      SEASONS[:all_season]
    end
  end

  # Check if it's time to change tires based on the month
  # @return [Boolean]
  def tire_change_season?
    month = Date.current.month
    # October-November for winter, March-April for summer
    [3, 4, 10, 11].include?(month)
  end

  # Get upcoming tire service reminders for a client
  # @param client [Client] the client
  # @return [Array<Hash>] list of reminders
  def get_reminders(client)
    reminders = []

    # Check last tire change
    last_booking = client.bookings
      .joins(:service_category)
      .where(service_categories: { name: ['Шиномонтаж', 'Сезонная замена шин'] })
      .where(status: 'completed')
      .order(created_at: :desc)
      .first

    if last_booking
      months_since = ((Date.current - last_booking.booking_date.to_date) / 30).to_i

      # Remind if last change was 5+ months ago during transition season
      if months_since >= 5 && tire_change_season?
        reminders << {
          type: 'seasonal_change',
          priority: 'high',
          message: "Вы меняли шины #{months_since} месяцев назад. Пора проверить состояние резины!",
          last_service_date: last_booking.booking_date,
          suggested_action: 'book_tire_change'
        }
      end
    elsif tire_change_season?
      # No tire change history - suggest during transition seasons
      reminders << {
        type: 'seasonal_reminder',
        priority: 'medium',
        message: seasonal_reminder_message,
        suggested_action: 'book_tire_change'
      }
    end

    # Check if user has registered cars
    if client.respond_to?(:cars) && client.cars.any?
      client.cars.each do |car|
        if car.respond_to?(:tire_change_date) && car.tire_change_date.present?
          months_since = ((Date.current - car.tire_change_date) / 30).to_i
          if months_since >= 5
            reminders << {
              type: 'car_tire_reminder',
              priority: 'medium',
              car: "#{car.brand} #{car.model}",
              message: "Шины на #{car.brand} #{car.model} не менялись #{months_since} месяцев",
              suggested_action: 'book_tire_change'
            }
          end
        end
      end
    end

    reminders
  end

  private

  def build_recommendation_context(client)
    {
      current_month: Date.current.month,
      current_season: current_recommended_season,
      is_transition_season: tire_change_season?,
      last_tire_booking: last_tire_booking(client),
      cars: client.respond_to?(:cars) ? client.cars.map { |c| { brand: c.brand, model: c.model } } : [],
      region: client.respond_to?(:region) ? client.region&.name : nil
    }
  end

  def should_recommend?(context)
    return false unless context[:is_transition_season]
    return true if context[:last_tire_booking].nil?

    months_since = ((Date.current - context[:last_tire_booking]) / 30).to_i
    months_since >= 5
  end

  def generate_recommendation(context)
    result = @openai.chat(
      messages: build_recommendation_messages(context),
      model: 'gpt-4.1-nano'
    )

    parse_recommendation_response(result['content'], context)
  rescue StandardError => e
    Rails.logger.error("Recommendation generation failed: #{e.message}")
    default_recommendation(context)
  end

  def build_recommendation_messages(context)
    [
      {
        role: 'system',
        content: <<~PROMPT
          Ты консультант по сезонной замене шин в Украине.
          Проанализируй контекст и дай рекомендацию о необходимости замены шин.

          Отвечай в формате JSON:
          {
            "needs_change": true/false,
            "urgency": "high/medium/low",
            "recommended_tire_type": "winter/summer/all_season",
            "reason": "краткое объяснение на русском",
            "tips": ["совет 1", "совет 2"]
          }
        PROMPT
      },
      {
        role: 'user',
        content: <<~CONTENT
          Текущий месяц: #{context[:current_month]}
          Рекомендуемый сезон: #{context[:current_season]}
          Последняя замена шин: #{context[:last_tire_booking] || 'неизвестно'}
          Автомобили: #{context[:cars].map { |c| "#{c[:brand]} #{c[:model]}" }.join(', ') || 'не указаны'}
          Регион: #{context[:region] || 'Украина'}
        CONTENT
      }
    ]
  end

  def build_vehicle_recommendation_messages(vehicle_info, season)
    [
      {
        role: 'system',
        content: <<~PROMPT
          Ты эксперт по шинам. Дай рекомендации по выбору шин для автомобиля.

          Отвечай в формате JSON:
          {
            "recommended_sizes": ["размер 1", "размер 2"],
            "top_brands": ["бренд 1", "бренд 2", "бренд 3"],
            "price_range": {"min": число, "max": число},
            "tips": ["совет по выбору 1", "совет 2"],
            "important_features": ["особенность 1", "особенность 2"]
          }
        PROMPT
      },
      {
        role: 'user',
        content: <<~CONTENT
          Автомобиль: #{vehicle_info[:brand]} #{vehicle_info[:model]} #{vehicle_info[:year]}
          Сезон: #{season}
        CONTENT
      }
    ]
  end

  def parse_recommendation_response(content, context)
    json = JSON.parse(content)
    {
      needs_change: json['needs_change'] || false,
      urgency: json['urgency'] || 'low',
      recommended_tire_type: json['recommended_tire_type'] || context[:current_season],
      reason: json['reason'] || '',
      tips: json['tips'] || [],
      generated_at: Time.current
    }
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse recommendation: #{e.message}")
    default_recommendation(context)
  end

  def parse_tire_recommendations(content)
    json = JSON.parse(content)
    {
      recommended_sizes: json['recommended_sizes'] || [],
      top_brands: json['top_brands'] || [],
      price_range: json['price_range'] || { min: 0, max: 0 },
      tips: json['tips'] || [],
      important_features: json['important_features'] || [],
      generated_at: Time.current
    }
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse tire recommendations: #{e.message}")
    { recommended_sizes: [], top_brands: [], price_range: {}, tips: [], important_features: [] }
  end

  def default_recommendation(context)
    {
      needs_change: context[:is_transition_season],
      urgency: 'medium',
      recommended_tire_type: context[:current_season],
      reason: seasonal_reminder_message,
      tips: default_tips(context[:current_season]),
      generated_at: Time.current
    }
  end

  def default_tips(season)
    case season
    when SEASONS[:winter]
      [
        'Зимние шины обеспечивают лучшее сцепление при температуре ниже +7°C',
        'Проверьте глубину протектора - минимум 4мм для зимних шин',
        'Не забудьте про запасное колесо'
      ]
    when SEASONS[:summer]
      [
        'Летние шины эффективны при температуре выше +7°C',
        'Проверьте давление в шинах перед летним сезоном',
        'Осмотрите шины на предмет повреждений после зимы'
      ]
    else
      [
        'Всесезонные шины - компромисс между летними и зимними',
        'Для экстремальных условий лучше использовать сезонные шины',
        'Регулярно проверяйте давление и состояние шин'
      ]
    end
  end

  def seasonal_reminder_message
    month = Date.current.month
    case month
    when 10, 11
      'Приближается зима! Рекомендуем заменить летние шины на зимние до первых заморозков.'
    when 3, 4
      'Весна пришла! Пора менять зимние шины на летние для лучшего сцепления и экономии топлива.'
    else
      'Проверьте состояние ваших шин и запланируйте сезонную замену заранее.'
    end
  end

  def last_tire_booking(client)
    booking = client.bookings
      .joins(:service_category)
      .where(service_categories: { name: ['Шиномонтаж', 'Сезонная замена шин'] })
      .where(status: 'completed')
      .order(created_at: :desc)
      .first

    booking&.booking_date&.to_date
  rescue StandardError
    nil
  end
end
