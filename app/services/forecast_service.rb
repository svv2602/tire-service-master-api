# frozen_string_literal: true

# Service for predicting load and providing staffing recommendations
# based on historical booking data
class ForecastService < ApplicationService
  DAYS_OF_WEEK = %w[sunday monday tuesday wednesday thursday friday saturday].freeze
  DEFAULT_LOOKBACK_WEEKS = 8
  MINIMUM_DATA_POINTS = 4

  def initialize(partner_or_service_point, options = {})
    @entity = partner_or_service_point
    @lookback_weeks = options[:lookback_weeks] || DEFAULT_LOOKBACK_WEEKS
    @forecast_days = options[:forecast_days] || 7
    @include_seasonality = options[:include_seasonality] != false
  end

  def call
    Result.new(
      success: true,
      data: {
        forecast: generate_forecast,
        recommendations: generate_recommendations,
        peak_days: identify_peak_days,
        historical_summary: historical_summary
      }
    )
  rescue StandardError => e
    Rails.logger.error("ForecastService error: #{e.message}")
    Result.new(success: false, error: e.message)
  end

  # Generate forecast for next N days
  def generate_forecast
    forecast_data = []
    today = Date.current

    (1..@forecast_days).each do |day_offset|
      forecast_date = today + day_offset.days
      day_of_week = forecast_date.wday

      predicted_bookings = predict_bookings_for_day(day_of_week, forecast_date)
      confidence = calculate_confidence(day_of_week)

      forecast_data << {
        date: forecast_date.strftime('%Y-%m-%d'),
        day_of_week: DAYS_OF_WEEK[day_of_week],
        predicted_bookings: predicted_bookings,
        confidence: confidence,
        load_indicator: calculate_load_indicator(predicted_bookings),
        is_peak_day: peak_day?(day_of_week, forecast_date)
      }
    end

    forecast_data
  end

  # Generate staffing and scheduling recommendations
  def generate_recommendations
    recommendations = []

    # Analyze each day of the forecast period
    forecast = generate_forecast
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
    end

    # Add weekly summary recommendation
    peak_days_this_week = forecast.select { |d| d[:is_peak_day] }
    if peak_days_this_week.any?
      recommendations << {
        type: 'weekly_summary',
        priority: 'medium',
        message: "Peak days this week: #{peak_days_this_week.map { |d| d[:day_of_week] }.join(', ')}",
        peak_days: peak_days_this_week.map { |d| d[:date] }
      }
    end

    # Add seasonal recommendation if applicable
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

  # Predict bookings for a specific day of week
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

    [base_prediction, 0].max
  end

  # Get historical booking counts for specific day of week
  def get_historical_data_for_day(day_of_week)
    end_date = Date.current
    start_date = end_date - (@lookback_weeks * 7).days

    # Get dates that match the day of week
    matching_dates = (start_date..end_date).select { |d| d.wday == day_of_week }

    matching_dates.map do |date|
      entity_bookings.where(booking_date: date).count
    end
  end

  # Calculate confidence level based on data availability
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

  # Calculate load indicator (free/medium/busy)
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

  # Check if day is typically a peak day
  def peak_day?(day_of_week, date = nil)
    patterns = analyze_day_of_week_patterns
    day_name = DAYS_OF_WEEK[day_of_week]
    patterns[day_name][:is_peak]
  end

  # Analyze patterns by day of week
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

  # Find busiest hours for a day of week
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

  # Calculate trend (increasing, decreasing, stable)
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

    # Compare first half to second half
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

  # Apply seasonal adjustment based on tire change seasons
  def apply_seasonal_adjustment(base_prediction, date)
    month = date.month

    # Peak seasons for tire services:
    # - March-April: Spring tire change
    # - October-November: Winter tire change
    seasonal_multiplier = case month
                          when 3, 4 then 1.4      # Spring peak
                          when 10, 11 then 1.5   # Winter peak (typically higher)
                          when 5, 9 then 1.2     # Shoulder seasons
                          when 12, 1, 2 then 0.8 # Winter slow period
                          when 6, 7, 8 then 0.9  # Summer slow period
                          else 1.0
                          end

    (base_prediction * seasonal_multiplier).round
  end

  # Check if seasonal peak is approaching
  def seasonal_peak_approaching?
    current_month = Date.current.month
    # Alert 2-3 weeks before peak seasons
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

  # Calculate suggested number of operators based on predicted load
  def calculate_suggested_operators(predicted_bookings)
    # Assume average 4 bookings per operator per day
    bookings_per_operator = 4
    min_operators = 1

    suggested = (predicted_bookings.to_f / bookings_per_operator).ceil
    [suggested, min_operators].max
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
