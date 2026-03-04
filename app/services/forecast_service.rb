# frozen_string_literal: true

# Service for predicting load and providing staffing recommendations
# based on historical booking data, with AI-enhanced analysis
#
# Combines statistical forecasting (weighted moving average + seasonality)
# with optional AI analysis for richer recommendations text.
#
# Usage:
#   result = ForecastService.new(partner, forecast_days: 7).call
#   result.data[:forecast]         # => array of daily forecasts
#   result.data[:recommendations]  # => staffing recommendations
#   result.data[:ai_insights]      # => AI-generated insights (if available)
class ForecastService < ApplicationService
  DAYS_OF_WEEK = %w[sunday monday tuesday wednesday thursday friday saturday].freeze
  DEFAULT_LOOKBACK_WEEKS = 8
  MINIMUM_DATA_POINTS = 4
  AI_FORECAST_CACHE_TTL = 6.hours.to_i

  # Ukrainian holidays that affect tire service demand
  HOLIDAYS = {
    [1, 1] => 'New Year',
    [1, 7] => 'Orthodox Christmas',
    [3, 8] => 'International Womens Day',
    [5, 1] => 'Labour Day',
    [5, 9] => 'Victory Day',
    [6, 28] => 'Constitution Day',
    [8, 24] => 'Independence Day',
    [10, 14] => 'Defenders Day',
    [12, 25] => 'Christmas Day'
  }.freeze

  def initialize(partner_or_service_point, options = {})
    @entity = partner_or_service_point
    @lookback_weeks = options[:lookback_weeks] || DEFAULT_LOOKBACK_WEEKS
    @forecast_days = options[:forecast_days] || 7
    @include_seasonality = options[:include_seasonality] != false
    @include_ai = options[:include_ai] != false
  end

  def call
    forecast_data = generate_forecast
    recommendations_data = generate_recommendations(forecast_data)
    peak_days_data = identify_peak_days

    data = {
      forecast: forecast_data,
      recommendations: recommendations_data,
      peak_days: peak_days_data,
      historical_summary: historical_summary
    }

    # Add AI-enhanced insights if enabled
    if @include_ai
      ai_insights = generate_ai_insights(forecast_data, recommendations_data)
      data[:ai_insights] = ai_insights if ai_insights
    end

    Result.new(success: true, data: data)
  rescue StandardError => e
    Rails.logger.error("ForecastService error: #{e.message}")
    Result.new(success: false, error: e.message)
  end

  # Generate forecast for next N days with hourly breakdown
  def generate_forecast
    forecast_data = []
    today = Date.current

    (1..@forecast_days).each do |day_offset|
      forecast_date = today + day_offset.days
      day_of_week = forecast_date.wday

      predicted_bookings = predict_bookings_for_day(day_of_week, forecast_date)
      confidence = calculate_confidence(day_of_week)
      hourly = predict_hourly_distribution(day_of_week, predicted_bookings)

      forecast_data << {
        date: forecast_date.strftime('%Y-%m-%d'),
        day_of_week: DAYS_OF_WEEK[day_of_week],
        predicted_bookings: predicted_bookings,
        confidence: confidence,
        load_indicator: calculate_load_indicator(predicted_bookings),
        is_peak_day: peak_day?(day_of_week, forecast_date),
        is_holiday: holiday?(forecast_date),
        holiday_name: holiday_name(forecast_date),
        hourly_forecast: hourly
      }
    end

    forecast_data
  end

  # Generate staffing and scheduling recommendations
  def generate_recommendations(forecast = nil)
    forecast ||= generate_forecast
    recommendations = []
    avg_bookings = historical_average_daily_bookings

    forecast.each do |day_forecast|
      if day_forecast[:predicted_bookings] > avg_bookings * 1.5
        recommendations << {
          date: day_forecast[:date],
          type: 'high_load',
          priority: 'high',
          message: "Expected high load on #{day_forecast[:day_of_week]}. Consider additional staff.",
          suggested_operators: calculate_suggested_operators(day_forecast[:predicted_bookings])
        }
      elsif day_forecast[:predicted_bookings] < avg_bookings * 0.5 && day_forecast[:predicted_bookings] > 0
        recommendations << {
          date: day_forecast[:date],
          type: 'low_load',
          priority: 'low',
          message: "Expected low load on #{day_forecast[:day_of_week]}. Opportunity for maintenance or training.",
          suggested_operators: calculate_suggested_operators(day_forecast[:predicted_bookings])
        }
      end

      # Holiday-specific recommendations
      if day_forecast[:is_holiday]
        recommendations << {
          date: day_forecast[:date],
          type: 'holiday',
          priority: 'medium',
          message: "#{day_forecast[:holiday_name]} - expect reduced demand. Consider adjusted hours.",
          holiday_name: day_forecast[:holiday_name]
        }
      end
    end

    # Weekly summary recommendation
    peak_days_this_week = forecast.select { |d| d[:is_peak_day] }
    if peak_days_this_week.any?
      recommendations << {
        type: 'weekly_summary',
        priority: 'medium',
        message: "Peak days this week: #{peak_days_this_week.map { |d| d[:day_of_week] }.join(', ')}",
        peak_days: peak_days_this_week.map { |d| d[:date] }
      }
    end

    # Seasonal recommendation
    if @include_seasonality && seasonal_peak_approaching?
      recommendations << {
        type: 'seasonal_alert',
        priority: 'high',
        message: 'Seasonal peak approaching (tire change season). Prepare for increased demand.',
        season: current_season
      }
    end

    recommendations
  end

  # Identify historical peak days
  def identify_peak_days
    day_stats = analyze_day_of_week_patterns

    day_stats.map do |day, stats|
      {
        day_of_week: day,
        average_bookings: stats[:average].round(1),
        max_bookings: stats[:max],
        is_peak: stats[:is_peak],
        busiest_hours: find_busiest_hours(DAYS_OF_WEEK.index(day))
      }
    end.sort_by { |d| -d[:average_bookings] }
  end

  # Historical data summary
  def historical_summary
    end_date = Date.current
    start_date = end_date - (@lookback_weeks * 7).days

    bookings = entity_bookings.where(booking_date: start_date..end_date)
    completed = bookings.where(status: 'completed')

    {
      period: {
        start_date: start_date.strftime('%Y-%m-%d'),
        end_date: end_date.strftime('%Y-%m-%d'),
        weeks: @lookback_weeks
      },
      totals: {
        total_bookings: bookings.count,
        completed_bookings: completed.count,
        cancelled_bookings: bookings.where(status: %w[cancelled_by_client cancelled_by_partner]).count,
        completion_rate: bookings.count > 0 ? (completed.count.to_f / bookings.count * 100).round(1) : 0
      },
      averages: {
        daily_average: (bookings.count.to_f / (@lookback_weeks * 7)).round(1),
        weekly_average: (bookings.count.to_f / @lookback_weeks).round(1)
      },
      trends: calculate_trend
    }
  end

  private

  def entity_bookings
    case @entity
    when Partner
      Booking.joins(:service_point).where(service_points: { partner_id: @entity.id })
    when ServicePoint
      @entity.bookings
    else
      Booking.none
    end
  end

  def entity_service_points
    case @entity
    when Partner
      @entity.service_points
    when ServicePoint
      ServicePoint.where(id: @entity.id)
    else
      ServicePoint.none
    end
  end

  # === Prediction ===

  # Predict bookings for a specific day of week considering date-specific factors
  def predict_bookings_for_day(day_of_week, forecast_date)
    historical_data = get_historical_data_for_day(day_of_week)
    return 0 if historical_data.empty?

    # Calculate weighted moving average (more recent data has higher weight)
    weights = historical_data.each_with_index.map { |_, i| 1.0 + (i * 0.1) }
    weighted_sum = historical_data.zip(weights).map { |v, w| v * w }.sum
    total_weight = weights.sum

    base_prediction = (weighted_sum / total_weight).round

    # Apply seasonal adjustment
    if @include_seasonality
      base_prediction = apply_seasonal_adjustment(base_prediction, forecast_date)
    end

    # Apply holiday adjustment
    if holiday?(forecast_date)
      base_prediction = (base_prediction * 0.3).round # Significant drop on holidays
    end

    # Apply day-before/after holiday adjustment
    if day_near_holiday?(forecast_date)
      base_prediction = (base_prediction * 0.7).round
    end

    [base_prediction, 0].max
  end

  # Predict hourly distribution for a given day
  def predict_hourly_distribution(day_of_week, total_bookings)
    return [] if total_bookings.zero?

    # Get historical hourly data for this day of week
    hourly_data = get_historical_hourly_data(day_of_week)

    if hourly_data.any?
      # Use actual historical distribution
      total_historical = hourly_data.values.sum.to_f
      return [] if total_historical.zero?

      hourly_data.map do |hour, count|
        predicted = (count.to_f / total_historical * total_bookings).round
        {
          hour: hour.to_i,
          predicted_bookings: [predicted, 0].max,
          confidence: calculate_hourly_confidence(hourly_data, hour)
        }
      end.sort_by { |h| h[:hour] }
    else
      # Fallback to typical distribution pattern
      typical_distribution(total_bookings)
    end
  end

  def typical_distribution(total_bookings)
    # Typical tire service hours distribution
    distribution = {
      8 => 0.05, 9 => 0.08, 10 => 0.12, 11 => 0.12,
      12 => 0.08, 13 => 0.08, 14 => 0.12, 15 => 0.12,
      16 => 0.10, 17 => 0.08, 18 => 0.05
    }

    distribution.map do |hour, ratio|
      {
        hour: hour,
        predicted_bookings: (total_bookings * ratio).round,
        confidence: 'low'
      }
    end
  end

  def get_historical_hourly_data(day_of_week)
    end_date = Date.current
    start_date = end_date - (@lookback_weeks * 7).days
    matching_dates = (start_date..end_date).select { |d| d.wday == day_of_week }

    entity_bookings
      .where(booking_date: matching_dates)
      .group("EXTRACT(HOUR FROM start_time)")
      .count
  end

  def calculate_hourly_confidence(hourly_data, hour)
    count = hourly_data[hour] || 0
    if count >= 10
      'high'
    elsif count >= 5
      'medium'
    else
      'low'
    end
  end

  # Get historical booking counts for specific day of week
  def get_historical_data_for_day(day_of_week)
    end_date = Date.current
    start_date = end_date - (@lookback_weeks * 7).days

    matching_dates = (start_date..end_date).select { |d| d.wday == day_of_week }

    matching_dates.map do |date|
      entity_bookings.where(booking_date: date).count
    end
  end

  # === Confidence ===

  def calculate_confidence(day_of_week)
    data_points = get_historical_data_for_day(day_of_week).reject(&:zero?).count

    if data_points >= MINIMUM_DATA_POINTS * 2
      'high'
    elsif data_points >= MINIMUM_DATA_POINTS
      'medium'
    else
      'low'
    end
  end

  # === Load Indicators ===

  def calculate_load_indicator(predicted_bookings)
    avg = historical_average_daily_bookings
    return 'free' if avg.zero?

    ratio = predicted_bookings.to_f / avg

    if ratio < 0.5
      'free'
    elsif ratio < 1.2
      'medium'
    else
      'busy'
    end
  end

  # === Peak Day Analysis ===

  def peak_day?(day_of_week, date = nil)
    patterns = analyze_day_of_week_patterns
    day_name = DAYS_OF_WEEK[day_of_week]
    return false unless patterns[day_name]

    patterns[day_name][:is_peak]
  end

  def analyze_day_of_week_patterns
    @day_patterns ||= begin
      patterns = {}
      overall_avg = historical_average_daily_bookings

      DAYS_OF_WEEK.each_with_index do |day_name, day_num|
        data = get_historical_data_for_day(day_num)
        next if data.empty?

        avg = data.sum.to_f / data.count
        patterns[day_name] = {
          average: avg,
          max: data.max,
          min: data.min,
          is_peak: avg > overall_avg * 1.2
        }
      end

      patterns
    end
  end

  def find_busiest_hours(day_of_week)
    end_date = Date.current
    start_date = end_date - (@lookback_weeks * 7).days

    matching_dates = (start_date..end_date).select { |d| d.wday == day_of_week }

    hour_counts = entity_bookings
                    .where(booking_date: matching_dates)
                    .group("EXTRACT(HOUR FROM start_time)")
                    .count

    return [] if hour_counts.empty?

    avg_count = hour_counts.values.sum.to_f / hour_counts.count

    hour_counts.select { |_, count| count > avg_count }
               .sort_by { |_, count| -count }
               .take(3)
               .map { |hour, count| { hour: hour.to_i, bookings: count } }
  end

  def historical_average_daily_bookings
    @avg_daily ||= begin
      end_date = Date.current
      start_date = end_date - (@lookback_weeks * 7).days
      days = (end_date - start_date).to_i

      total = entity_bookings.where(booking_date: start_date..end_date).count
      days > 0 ? total.to_f / days : 0
    end
  end

  # === Trend Analysis ===

  def calculate_trend
    weeks_data = []
    end_date = Date.current

    @lookback_weeks.times do |week_offset|
      week_end = end_date - (week_offset * 7).days
      week_start = week_end - 6.days
      count = entity_bookings.where(booking_date: week_start..week_end).count
      weeks_data.unshift(count)
    end

    return { direction: 'insufficient_data', change_percent: 0 } if weeks_data.length < 2

    mid = weeks_data.length / 2
    first_half_avg = weeks_data[0...mid].sum.to_f / mid
    second_half_avg = weeks_data[mid..].sum.to_f / (weeks_data.length - mid)

    return { direction: 'stable', change_percent: 0 } if first_half_avg.zero?

    change = ((second_half_avg - first_half_avg) / first_half_avg * 100).round(1)

    direction = if change > 10
                  'increasing'
                elsif change < -10
                  'decreasing'
                else
                  'stable'
                end

    { direction: direction, change_percent: change }
  end

  # === Seasonal Adjustments ===

  def apply_seasonal_adjustment(base_prediction, date)
    month = date.month

    # Peak seasons for tire services in Ukraine:
    # - March-April: Spring tire change (winter -> summer)
    # - October-November: Winter tire change (summer -> winter)
    seasonal_multiplier = case month
                          when 3, 4 then 1.4      # Spring peak
                          when 10, 11 then 1.5    # Winter peak (typically higher)
                          when 5, 9 then 1.2      # Shoulder seasons
                          when 12, 1, 2 then 0.8  # Winter slow period
                          when 6, 7, 8 then 0.9   # Summer slow period
                          else 1.0
                          end

    (base_prediction * seasonal_multiplier).round
  end

  def seasonal_peak_approaching?
    current_month = Date.current.month
    [2, 3, 9, 10].include?(current_month)
  end

  def current_season
    month = Date.current.month
    case month
    when 3, 4, 5 then 'spring'
    when 6, 7, 8 then 'summer'
    when 9, 10, 11 then 'autumn'
    else 'winter'
    end
  end

  # === Holiday Detection ===

  def holiday?(date)
    HOLIDAYS.key?([date.month, date.day])
  end

  def holiday_name(date)
    HOLIDAYS[[date.month, date.day]]
  end

  def day_near_holiday?(date)
    yesterday = date - 1.day
    tomorrow = date + 1.day
    holiday?(yesterday) || holiday?(tomorrow)
  end

  # === Staffing ===

  def calculate_suggested_operators(predicted_bookings)
    bookings_per_operator = 4
    min_operators = 1

    suggested = (predicted_bookings.to_f / bookings_per_operator).ceil
    [suggested, min_operators].max
  end

  # === AI-Enhanced Insights ===

  # Generate AI-powered insights and recommendations text
  def generate_ai_insights(forecast, recommendations)
    entity_name = case @entity
                  when Partner then "partner_#{@entity.id}"
                  when ServicePoint then "sp_#{@entity.id}"
                  else 'unknown'
                  end

    cache_key = "ai_forecast:#{entity_name}:#{Date.current}"
    cached = Rails.cache.read(cache_key)
    return cached if cached

    summary = historical_summary
    trend = summary[:trends]

    result = AiRequestWrapper.call(
      operation: 'booking_load_forecast',
      service_name: 'forecast',
      model: 'gpt-4.1-nano'
    ) do
      openai_service.chat_completion(
        build_ai_forecast_prompt(forecast, recommendations, summary, trend),
        model: 'gpt-4.1-nano',
        max_tokens: 600,
        temperature: 0.3
      )
    end

    if result.success?
      insights = parse_ai_insights(extract_content(result.data))
      Rails.cache.write(cache_key, insights, expires_in: AI_FORECAST_CACHE_TTL)
      insights
    else
      Rails.logger.warn "[ForecastService] AI insights unavailable: #{result.error}"
      fallback_insights(forecast, trend)
    end
  rescue StandardError => e
    Rails.logger.error "[ForecastService] AI insights error: #{e.message}"
    fallback_insights(forecast, calculate_trend)
  end

  def openai_service
    @openai_service ||= OpenaiService.new
  end

  def build_ai_forecast_prompt(forecast, recommendations, summary, trend)
    forecast_text = forecast.map do |day|
      "#{day[:date]} (#{day[:day_of_week]}): #{day[:predicted_bookings]} bookings, load: #{day[:load_indicator]}"
    end.join("\n")

    high_priority = recommendations.select { |r| r[:priority] == 'high' }
    alerts_text = high_priority.map { |r| "- #{r[:message]}" }.join("\n")

    <<~PROMPT
      You are a business analytics assistant for a tire service (shynomontazh) in Ukraine.
      Analyze the following booking forecast and provide actionable insights in Russian.

      Historical data:
      - Period: #{summary[:period][:weeks]} weeks
      - Total bookings: #{summary[:totals][:total_bookings]}
      - Daily average: #{summary[:averages][:daily_average]}
      - Trend: #{trend[:direction]} (#{trend[:change_percent]}%)
      - Current season: #{current_season}

      Upcoming week forecast:
      #{forecast_text}

      High priority alerts:
      #{alerts_text.presence || 'None'}

      Provide in Russian:
      1. summary: 2-3 sentence overview of the upcoming week
      2. key_insight: the most important observation
      3. action_items: 2-3 specific action items for the partner
      4. risk_factors: any risk factors to watch

      Respond ONLY with valid JSON:
      {"summary": "...", "key_insight": "...", "action_items": ["..."], "risk_factors": ["..."]}
    PROMPT
  end

  def extract_content(data)
    return '' unless data.is_a?(Hash)

    data.dig('choices', 0, 'message', 'content') || ''
  end

  def parse_ai_insights(content)
    return fallback_insights([], calculate_trend) if content.blank?

    cleaned = content.strip
    cleaned = cleaned.gsub(/\A```json\n?/, '').gsub(/\n?```\z/, '') if cleaned.start_with?('```')
    json = JSON.parse(cleaned)

    {
      summary: json['summary'].to_s,
      key_insight: json['key_insight'].to_s,
      action_items: Array(json['action_items']),
      risk_factors: Array(json['risk_factors']),
      generated_at: Time.current,
      ai_generated: true
    }
  rescue JSON::ParserError => e
    Rails.logger.error "[ForecastService] Failed to parse AI insights: #{e.message}"
    fallback_insights([], calculate_trend)
  end

  def fallback_insights(forecast, trend)
    summary = case trend[:direction]
              when 'increasing'
                "Demand is growing (#{trend[:change_percent]}% increase). Prepare for higher load."
              when 'decreasing'
                "Demand is declining (#{trend[:change_percent]}% decrease). Consider promotional activities."
              else
                'Demand is stable. Maintain current staffing levels.'
              end

    action_items = []
    if seasonal_peak_approaching?
      action_items << 'Prepare for seasonal tire change peak'
    end
    action_items << 'Review staffing levels for the upcoming week'

    {
      summary: summary,
      key_insight: "Trend: #{trend[:direction]}",
      action_items: action_items,
      risk_factors: [],
      generated_at: Time.current,
      ai_generated: false
    }
  end

  # Result struct for service responses
  class Result
    attr_reader :data, :error

    def initialize(success:, data: nil, error: nil)
      @success = success
      @data = data
      @error = error
    end

    def success?
      @success
    end
  end
end
