# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

# Service for Google Calendar integration
# Handles OAuth authorization and calendar synchronization
class GoogleCalendarService < ApplicationService
  GOOGLE_AUTH_URL = 'https://accounts.google.com/o/oauth2/v2/auth'
  GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token'
  GOOGLE_CALENDAR_API_URL = 'https://www.googleapis.com/calendar/v3'
  SCOPES = [
    'https://www.googleapis.com/auth/calendar.events',
    'https://www.googleapis.com/auth/calendar.readonly'
  ].freeze

  def initialize(partner_or_service_point)
    @resource = partner_or_service_point
    @settings = load_calendar_settings
  end

  # Generate OAuth authorization URL for partner
  # @param redirect_uri [String] callback URL after authorization
  # @param state [String] state parameter for security
  # @return [String] authorization URL
  def authorization_url(redirect_uri:, state: nil)
    params = {
      client_id: google_client_id,
      redirect_uri: redirect_uri,
      response_type: 'code',
      scope: SCOPES.join(' '),
      access_type: 'offline',
      prompt: 'consent'
    }
    params[:state] = state if state

    "#{GOOGLE_AUTH_URL}?#{URI.encode_www_form(params)}"
  end

  # Exchange authorization code for access tokens
  # @param code [String] authorization code from Google
  # @param redirect_uri [String] must match the one used in authorization
  # @return [Hash] tokens with access_token, refresh_token, expires_in
  def exchange_code(code:, redirect_uri:)
    uri = URI(GOOGLE_TOKEN_URL)
    response = Net::HTTP.post_form(uri, {
      code: code,
      client_id: google_client_id,
      client_secret: google_client_secret,
      redirect_uri: redirect_uri,
      grant_type: 'authorization_code'
    })

    result = JSON.parse(response.body)

    if result['access_token']
      save_tokens(result)
      { success: true, tokens: result }
    else
      { success: false, error: result['error_description'] || result['error'] }
    end
  rescue StandardError => e
    log_error("Token exchange failed: #{e.message}")
    { success: false, error: e.message }
  end

  # Refresh access token using refresh token
  # @return [Hash] new tokens
  def refresh_access_token
    return { success: false, error: 'No refresh token' } unless @settings&.refresh_token

    uri = URI(GOOGLE_TOKEN_URL)
    response = Net::HTTP.post_form(uri, {
      refresh_token: @settings.refresh_token,
      client_id: google_client_id,
      client_secret: google_client_secret,
      grant_type: 'refresh_token'
    })

    result = JSON.parse(response.body)

    if result['access_token']
      update_access_token(result['access_token'], result['expires_in'])
      { success: true, access_token: result['access_token'] }
    else
      { success: false, error: result['error_description'] || result['error'] }
    end
  rescue StandardError => e
    log_error("Token refresh failed: #{e.message}")
    { success: false, error: e.message }
  end

  # Sync a booking to Google Calendar
  # @param booking [Booking] booking to sync
  # @return [Hash] result with calendar_event_id
  def sync_booking(booking)
    ensure_valid_token!

    event = build_calendar_event(booking)

    if booking.google_calendar_event_id.present?
      update_calendar_event(booking.google_calendar_event_id, event)
    else
      create_calendar_event(event, booking)
    end
  rescue StandardError => e
    log_error("Booking sync failed: #{e.message}")
    { success: false, error: e.message }
  end

  # Delete booking from Google Calendar
  # @param booking [Booking] booking to remove
  # @return [Hash] result
  def delete_booking(booking)
    return { success: true } unless booking.google_calendar_event_id.present?

    ensure_valid_token!

    calendar_id = @settings.calendar_id || 'primary'
    uri = URI("#{GOOGLE_CALENDAR_API_URL}/calendars/#{calendar_id}/events/#{booking.google_calendar_event_id}")

    request = Net::HTTP::Delete.new(uri)
    request['Authorization'] = "Bearer #{@settings.access_token}"

    response = execute_request(uri, request)

    if response.code.to_i == 204 || response.code.to_i == 200 || response.code.to_i == 404
      booking.update(google_calendar_event_id: nil)
      { success: true }
    else
      { success: false, error: "Delete failed: #{response.code}" }
    end
  rescue StandardError => e
    log_error("Booking delete from calendar failed: #{e.message}")
    { success: false, error: e.message }
  end

  # Get list of user's calendars
  # @return [Array<Hash>] calendars
  def list_calendars
    ensure_valid_token!

    uri = URI("#{GOOGLE_CALENDAR_API_URL}/users/me/calendarList")
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{@settings.access_token}"

    response = execute_request(uri, request)
    result = JSON.parse(response.body)

    if result['items']
      { success: true, calendars: result['items'].map { |c| { id: c['id'], name: c['summary'] } } }
    else
      { success: false, error: result['error']&.dig('message') || 'Failed to list calendars' }
    end
  rescue StandardError => e
    log_error("List calendars failed: #{e.message}")
    { success: false, error: e.message }
  end

  # Check if calendar integration is connected
  # @return [Boolean]
  def connected?
    @settings&.access_token.present? && @settings&.refresh_token.present?
  end

  # Disconnect Google Calendar
  # @return [Hash] result
  def disconnect
    return { success: true } unless @settings

    @settings.update(
      access_token: nil,
      refresh_token: nil,
      token_expires_at: nil,
      calendar_id: nil
    )

    { success: true }
  rescue StandardError => e
    { success: false, error: e.message }
  end

  # Set the calendar to use for syncing
  # @param calendar_id [String] Google Calendar ID
  # @return [Hash] result
  def set_calendar(calendar_id)
    return { success: false, error: 'Not connected' } unless connected?

    @settings.update(calendar_id: calendar_id)
    { success: true }
  rescue StandardError => e
    { success: false, error: e.message }
  end

  # Sync all future bookings to calendar
  # @return [Hash] result with sync count
  def sync_all_bookings
    return { success: false, error: 'Not connected' } unless connected?

    bookings = @resource.is_a?(Partner) ?
      Booking.joins(:service_point).where(service_points: { partner_id: @resource.id }) :
      @resource.bookings

    future_bookings = bookings.where('booking_date >= ?', Date.current)
                              .where(status: %w[pending confirmed in_progress])

    synced = 0
    errors = []

    future_bookings.find_each do |booking|
      result = sync_booking(booking)
      if result[:success]
        synced += 1
      else
        errors << { booking_id: booking.id, error: result[:error] }
      end
    end

    { success: true, synced: synced, errors: errors }
  rescue StandardError => e
    { success: false, error: e.message }
  end

  private

  def google_client_id
    ENV.fetch('GOOGLE_CLIENT_ID', nil)
  end

  def google_client_secret
    ENV.fetch('GOOGLE_CLIENT_SECRET', nil)
  end

  def load_calendar_settings
    return nil unless @resource

    if @resource.is_a?(Partner)
      @resource.google_calendar_setting || @resource.build_google_calendar_setting
    else
      @resource.google_calendar_setting || @resource.build_google_calendar_setting
    end
  end

  def save_tokens(tokens)
    return unless @settings

    @settings.update(
      access_token: tokens['access_token'],
      refresh_token: tokens['refresh_token'] || @settings.refresh_token,
      token_expires_at: Time.current + tokens['expires_in'].to_i.seconds
    )
  end

  def update_access_token(access_token, expires_in)
    return unless @settings

    @settings.update(
      access_token: access_token,
      token_expires_at: Time.current + expires_in.to_i.seconds
    )
  end

  def ensure_valid_token!
    return if token_valid?

    result = refresh_access_token
    raise "Token refresh failed: #{result[:error]}" unless result[:success]
  end

  def token_valid?
    @settings&.access_token.present? &&
      @settings&.token_expires_at &&
      @settings.token_expires_at > Time.current + 1.minute
  end

  def build_calendar_event(booking)
    start_datetime = "#{booking.booking_date}T#{booking.start_time}"
    end_datetime = "#{booking.booking_date}T#{booking.end_time}"

    service_names = booking.booking_services.includes(:service).map { |bs| bs.service.name }.join(', ')
    client_info = booking.client ? "#{booking.client.first_name} #{booking.client.last_name}" : booking.client_name
    phone = booking.client&.phone || booking.client_phone

    {
      summary: "#{service_names} - #{client_info}",
      description: build_event_description(booking),
      start: {
        dateTime: DateTime.parse(start_datetime).rfc3339,
        timeZone: 'Europe/Kiev'
      },
      end: {
        dateTime: DateTime.parse(end_datetime).rfc3339,
        timeZone: 'Europe/Kiev'
      },
      location: booking.service_point.full_address,
      colorId: event_color_for_status(booking.status),
      reminders: {
        useDefault: false,
        overrides: [
          { method: 'popup', minutes: 30 },
          { method: 'popup', minutes: 10 }
        ]
      }
    }
  end

  def build_event_description(booking)
    parts = []
    parts << "📋 Запись ##{booking.id}"
    parts << "👤 Клиент: #{booking.client&.full_name || booking.client_name}"
    parts << "📱 Телефон: #{booking.client&.phone || booking.client_phone}" if booking.client&.phone || booking.client_phone
    parts << "🚗 Авто: #{booking.car_info}" if booking.car_info.present?
    parts << "📍 Точка: #{booking.service_point.name}"
    parts << "💰 Статус: #{I18n.t("booking.status.#{booking.status}", default: booking.status)}"
    parts << ""
    parts << "Услуги:"
    booking.booking_services.includes(:service).each do |bs|
      parts << "  • #{bs.service.name}"
    end
    parts << ""
    parts << "Примечания: #{booking.notes}" if booking.notes.present?
    parts.join("\n")
  end

  def event_color_for_status(status)
    case status
    when 'pending' then '5'  # yellow
    when 'confirmed' then '10' # green
    when 'in_progress' then '6' # orange
    when 'completed' then '2' # dark green
    when 'cancelled' then '4' # red
    else '8' # gray
    end
  end

  def create_calendar_event(event, booking)
    calendar_id = @settings.calendar_id || 'primary'
    uri = URI("#{GOOGLE_CALENDAR_API_URL}/calendars/#{calendar_id}/events")

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@settings.access_token}"
    request['Content-Type'] = 'application/json'
    request.body = event.to_json

    response = execute_request(uri, request)
    result = JSON.parse(response.body)

    if result['id']
      booking.update(google_calendar_event_id: result['id'])
      { success: true, event_id: result['id'] }
    else
      { success: false, error: result['error']&.dig('message') || 'Failed to create event' }
    end
  end

  def update_calendar_event(event_id, event)
    calendar_id = @settings.calendar_id || 'primary'
    uri = URI("#{GOOGLE_CALENDAR_API_URL}/calendars/#{calendar_id}/events/#{event_id}")

    request = Net::HTTP::Put.new(uri)
    request['Authorization'] = "Bearer #{@settings.access_token}"
    request['Content-Type'] = 'application/json'
    request.body = event.to_json

    response = execute_request(uri, request)
    result = JSON.parse(response.body)

    if result['id']
      { success: true, event_id: result['id'] }
    else
      { success: false, error: result['error']&.dig('message') || 'Failed to update event' }
    end
  end

  def execute_request(uri, request)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.request(request)
  end
end
