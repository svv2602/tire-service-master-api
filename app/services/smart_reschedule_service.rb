# frozen_string_literal: true

# Smart Reschedule Service
# Suggests alternative booking slots based on:
# - Client preferences (preferred time of day, day of week from history)
# - Service point load/occupancy
# - Nearby service points availability
# - Original booking constraints (same service category, car type)
class SmartRescheduleService < ApplicationService
  MAX_SUGGESTIONS = 6
  DAYS_TO_SEARCH = 14
  HISTORY_LOOKBACK_DAYS = 180

  # Score weights for ranking alternatives
  WEIGHTS = {
    time_preference: 30,   # Match client's preferred time
    day_preference: 20,    # Match client's preferred day of week
    low_occupancy: 25,     # Prefer less busy slots
    proximity: 15,         # Prefer same or nearby service point
    sooner: 10             # Prefer sooner dates
  }.freeze

  def initialize(booking, options = {})
    @booking = booking
    @max_suggestions = options.fetch(:max_suggestions, MAX_SUGGESTIONS)
    @include_other_points = options.fetch(:include_other_points, false)
    @days_to_search = options.fetch(:days_to_search, DAYS_TO_SEARCH)
  end

  def call
    preferences = analyze_client_preferences
    candidates = collect_candidate_slots(preferences)
    ranked = rank_candidates(candidates, preferences)

    {
      success: true,
      suggestions: ranked.first(@max_suggestions),
      preferences: preferences,
      search_params: {
        days_searched: @days_to_search,
        include_other_points: @include_other_points,
        original_booking_id: @booking.id
      }
    }
  rescue StandardError => e
    log_error("Failed to suggest alternatives: #{e.message}")
    { success: false, error: e.message, suggestions: [] }
  end

  private

  # Analyze client's booking history to determine preferences
  def analyze_client_preferences
    history = client_booking_history
    return default_preferences if history.empty?

    time_counts = Hash.new(0)
    day_counts = Hash.new(0)

    history.each do |b|
      hour = b.start_time&.hour
      time_counts[hour] += 1 if hour
      day_counts[b.booking_date.wday] += 1
    end

    preferred_hour = time_counts.max_by { |_, v| v }&.first
    preferred_wday = day_counts.max_by { |_, v| v }&.first

    {
      preferred_hour: preferred_hour || @booking.start_time&.hour || 10,
      preferred_wday: preferred_wday,
      total_bookings: history.size,
      preferred_time_range: preferred_time_range(preferred_hour),
      preferred_service_point_id: @booking.service_point_id
    }
  end

  def default_preferences
    {
      preferred_hour: @booking.start_time&.hour || 10,
      preferred_wday: nil,
      total_bookings: 0,
      preferred_time_range: preferred_time_range(@booking.start_time&.hour || 10),
      preferred_service_point_id: @booking.service_point_id
    }
  end

  # Classify preferred time into morning/afternoon/evening range
  def preferred_time_range(hour)
    return 'morning' if hour.nil?

    case hour
    when 8..11 then 'morning'
    when 12..15 then 'afternoon'
    when 16..20 then 'evening'
    else 'morning'
    end
  end

  def client_booking_history
    return [] unless @booking.client_id

    Booking.where(client_id: @booking.client_id)
           .where(status: %w[completed confirmed in_progress])
           .where('booking_date >= ?', Date.current - HISTORY_LOOKBACK_DAYS.days)
           .where.not(id: @booking.id)
           .order(booking_date: :desc)
           .limit(20)
  end

  # Collect available slots from service points
  def collect_candidate_slots(preferences)
    candidates = []
    service_point_ids = [@booking.service_point_id]

    if @include_other_points
      nearby_points = find_nearby_service_points
      service_point_ids += nearby_points.map(&:id)
    end

    start_date = [Date.current, Date.tomorrow].max
    end_date = start_date + @days_to_search.days

    service_point_ids.each do |sp_id|
      (start_date..end_date).each do |date|
        slots = fetch_available_slots(sp_id, date)
        slots.each do |slot|
          candidates << build_candidate(slot, sp_id, date)
        end
      end
    end

    candidates
  end

  def fetch_available_slots(service_point_id, date)
    if @booking.service_category_id.present?
      DynamicAvailabilityService.available_slots_for_category(
        service_point_id, date, @booking.service_category_id
      ) || []
    else
      DynamicAvailabilityService.available_times_for_date(
        service_point_id, date
      ) || []
    end
  rescue StandardError => e
    log_error("Error fetching slots for SP #{service_point_id} on #{date}: #{e.message}")
    []
  end

  def build_candidate(slot, service_point_id, date)
    start_time = slot[:start_time] || slot[:datetime]
    hour = extract_hour(start_time)
    occupancy = calculate_occupancy(slot)

    {
      service_point_id: service_point_id,
      date: date.to_s,
      start_time: format_time(start_time),
      hour: hour,
      wday: date.wday,
      occupancy_percent: occupancy,
      available_posts: slot[:available_posts] || slot[:free_posts] || 1,
      total_posts: slot[:total_posts] || 1,
      is_original_point: service_point_id == @booking.service_point_id
    }
  end

  def extract_hour(time_value)
    case time_value
    when Time, DateTime then time_value.hour
    when String
      if time_value.include?(':')
        time_value.split(':').first.to_i
      else
        Time.parse(time_value).hour
      end
    else
      10
    end
  end

  def format_time(time_value)
    case time_value
    when Time, DateTime then time_value.strftime('%H:%M')
    when String
      if time_value.match?(/^\d{2}:\d{2}$/)
        time_value
      else
        Time.parse(time_value).strftime('%H:%M')
      end
    else
      '10:00'
    end
  end

  def calculate_occupancy(slot)
    total = (slot[:total_posts] || 1).to_f
    available = (slot[:available_posts] || slot[:free_posts] || 0).to_f
    return 0 if total.zero?

    (((total - available) / total) * 100).round
  end

  # Rank candidates by weighted score
  def rank_candidates(candidates, preferences)
    scored = candidates.map do |c|
      score = calculate_score(c, preferences)
      c.merge(score: score)
    end

    scored.sort_by { |c| -c[:score] }
          .map { |c| format_suggestion(c) }
  end

  def calculate_score(candidate, preferences)
    score = 0.0

    # Time preference score: closer to preferred hour = higher score
    hour_diff = (candidate[:hour] - preferences[:preferred_hour]).abs
    time_score = [1.0 - (hour_diff / 12.0), 0].max
    score += time_score * WEIGHTS[:time_preference]

    # Day preference score
    if preferences[:preferred_wday]
      day_match = candidate[:wday] == preferences[:preferred_wday] ? 1.0 : 0.0
      score += day_match * WEIGHTS[:day_preference]
    end

    # Low occupancy score: prefer less busy slots
    occupancy_score = 1.0 - (candidate[:occupancy_percent] / 100.0)
    score += occupancy_score * WEIGHTS[:low_occupancy]

    # Proximity score: prefer original service point
    proximity_score = candidate[:is_original_point] ? 1.0 : 0.3
    score += proximity_score * WEIGHTS[:proximity]

    # Sooner score: prefer closer dates
    days_away = (Date.parse(candidate[:date]) - Date.current).to_i
    sooner_score = [1.0 - (days_away.to_f / @days_to_search), 0].max
    score += sooner_score * WEIGHTS[:sooner]

    score.round(2)
  end

  def format_suggestion(candidate)
    service_point = ServicePoint.find_by(id: candidate[:service_point_id])
    {
      date: candidate[:date],
      start_time: candidate[:start_time],
      service_point_id: candidate[:service_point_id],
      service_point_name: service_point&.name,
      service_point_address: service_point&.address,
      is_original_point: candidate[:is_original_point],
      occupancy_percent: candidate[:occupancy_percent],
      available_posts: candidate[:available_posts],
      score: candidate[:score],
      day_of_week: I18n.l(Date.parse(candidate[:date]), format: '%A')
    }
  rescue StandardError
    candidate.slice(:date, :start_time, :service_point_id, :is_original_point,
                    :occupancy_percent, :available_posts, :score)
  end

  # Find nearby service points in the same city with same services
  def find_nearby_service_points
    sp = ServicePoint.find_by(id: @booking.service_point_id)
    return [] unless sp

    scope = ServicePoint.where(city_id: sp.city_id)
                        .where(is_active: true)
                        .where(work_status: 'working')
                        .where.not(id: sp.id)

    if @booking.service_category_id.present?
      scope = scope.joins(:service_point_services)
                   .joins('INNER JOIN services ON services.id = service_point_services.service_id')
                   .where(services: { service_category_id: @booking.service_category_id })
    end

    scope.distinct.limit(3)
  end
end
