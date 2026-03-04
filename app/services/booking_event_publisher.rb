# frozen_string_literal: true

# BookingEventPublisher - event-based notification publisher for Booking model.
#
# Replaces 15+ notification callbacks in Booking with a single after_commit hook.
# Detects the most important event from saved_changes and publishes it via
# BookingNotificationJob, ensuring exactly one notification event per save.
#
# Event priority (highest to lowest):
#   1. booking_created       - new booking
#   2. booking_cancelled     - status -> cancelled_by_client / cancelled_by_partner
#   3. booking_confirmed     - status -> confirmed
#   4. booking_completed     - status -> completed
#   5. booking_in_progress   - status -> in_progress
#   6. booking_no_show       - status -> no_show
#   7. booking_time_changed  - start_time or booking_date changed
#   8. booking_location_changed - service_point_id changed
#   9. booking_client_info_changed - recipient name/phone/email changed
#
# Usage:
#   BookingEventPublisher.call(booking)
#
class BookingEventPublisher < ApplicationService
  # All detectable events in priority order (most important first).
  # When multiple changes happen in one save, only the highest-priority event fires.
  EVENT_PRIORITY = %i[
    booking_created
    booking_cancelled
    booking_confirmed
    booking_completed
    booking_in_progress
    booking_no_show
    booking_time_changed
    booking_location_changed
    booking_client_info_changed
  ].freeze

  # Map status values to event names
  STATUS_EVENT_MAP = {
    'confirmed'            => :booking_confirmed,
    'cancelled_by_client'  => :booking_cancelled,
    'cancelled_by_partner' => :booking_cancelled,
    'completed'            => :booking_completed,
    'in_progress'          => :booking_in_progress,
    'no_show'              => :booking_no_show
  }.freeze

  # Notification routing matrix: event -> list of notification dispatches.
  # Each entry: { type: <notification_type>, recipient: <method>, channel_hint: <optional> }
  ROUTING_MATRIX = {
    booking_created: [
      { type: 'booking_created',          recipient: :client_email },
      { type: 'admin_new_booking',        recipient: :admin_emails },
      { type: 'telegram_booking_created', recipient: :client_telegram },
      { type: 'partner_new_booking',      recipient: :partner_email },
      { type: 'push_partner_new_booking', recipient: :partner_push },
      { type: 'telegram_partner_new_booking', recipient: :partner_telegram },
      { type: 'push_operator_new_booking', recipient: :operator_push }
    ],
    booking_confirmed: [
      { type: 'booking_confirmed', recipient: :client_email }
    ],
    booking_cancelled: [
      { type: 'booking_cancelled',                recipient: :client_email },
      { type: 'admin_booking_cancelled',          recipient: :admin_emails },
      { type: 'telegram_booking_cancelled',       recipient: :client_telegram },
      { type: 'partner_booking_cancelled',        recipient: :partner_email },
      { type: 'push_partner_booking_cancelled',   recipient: :partner_push },
      { type: 'telegram_partner_booking_cancelled', recipient: :partner_telegram },
      { type: 'push_operator_booking_cancelled',  recipient: :operator_push }
    ],
    booking_completed: [
      { type: 'service_completed', recipient: :client_email }
    ],
    booking_in_progress: [],
    booking_no_show: [],
    booking_time_changed: [
      { type: 'booking_time_changed',                recipient: :client_email },
      { type: 'admin_booking_changed',               recipient: :admin_emails },
      { type: 'telegram_booking_time_changed',       recipient: :client_telegram }
    ],
    booking_location_changed: [
      { type: 'booking_location_changed',            recipient: :client_email },
      { type: 'admin_booking_changed',               recipient: :admin_emails },
      { type: 'telegram_booking_location_changed',   recipient: :client_telegram }
    ],
    booking_client_info_changed: [
      { type: 'booking_client_info_changed',  recipient: :client_email },
      { type: 'admin_booking_changed',        recipient: :admin_emails }
    ]
  }.freeze

  # @param booking [Booking] the booking that was just committed
  def initialize(booking)
    @booking = booking
  end

  # Detect the event and dispatch all notifications for it.
  # @return [Symbol, nil] the detected event name, or nil if no event
  def call
    event = detect_event
    return nil unless event

    log_info "Event detected: #{event} for booking ##{@booking.id}"

    dispatch_notifications(event)

    event
  end

  # Detect the highest-priority event from the booking's saved_changes.
  # @return [Symbol, nil]
  def detect_event
    events = collect_events
    return nil if events.empty?

    # Return the event with the highest priority (lowest index in EVENT_PRIORITY)
    events.min_by { |e| EVENT_PRIORITY.index(e) || EVENT_PRIORITY.size }
  end

  private

  # Collect all events that apply to this save.
  # @return [Array<Symbol>]
  def collect_events
    events = []

    # 1. New record?
    if @booking.previously_new_record?
      events << :booking_created
      return events # Creation is always the only event
    end

    changes = @booking.saved_changes

    # 2. Status changed?
    if changes.key?('status')
      new_status = changes['status'].last
      status_event = STATUS_EVENT_MAP[new_status]
      events << status_event if status_event
    end

    # 3. Time changed?
    if changes.key?('start_time') || changes.key?('booking_date')
      events << :booking_time_changed
    end

    # 4. Location changed?
    if changes.key?('service_point_id')
      events << :booking_location_changed
    end

    # 5. Client info changed?
    client_fields = %w[
      service_recipient_first_name
      service_recipient_last_name
      service_recipient_phone
      service_recipient_email
    ]
    if client_fields.any? { |f| changes.key?(f) }
      events << :booking_client_info_changed
    end

    events
  end

  # Dispatch all notifications for the given event.
  # @param event [Symbol]
  def dispatch_notifications(event)
    routes = ROUTING_MATRIX[event] || []

    routes.each do |route|
      dispatch_single(route)
    end
  end

  # Dispatch a single notification route.
  # @param route [Hash] { type:, recipient: }
  def dispatch_single(route)
    case route[:recipient]
    when :client_email
      BookingNotificationJob.perform_later(@booking.id, route[:type])
    when :client_telegram
      BookingNotificationJob.perform_later(@booking.id, route[:type])
    when :admin_emails
      admin_email_list.each do |email|
        BookingNotificationJob.perform_later(@booking.id, route[:type], email)
      end
    when :partner_email
      partner_user = @booking.service_point&.partner&.user
      return unless partner_user

      BookingNotificationJob.perform_later(@booking.id, route[:type], partner_user.email)
    when :partner_push
      BookingNotificationJob.perform_later(@booking.id, route[:type])
    when :partner_telegram
      BookingNotificationJob.perform_later(@booking.id, route[:type])
    when :operator_push
      dispatch_operator_notifications(route[:type])
    end
  rescue StandardError => e
    log_error "Failed to dispatch notification #{route[:type]} for booking ##{@booking.id}: #{e.message}"
  end

  # Send push notifications to all active operators of the service point.
  # @param notification_type [String]
  def dispatch_operator_notifications(notification_type)
    return unless @booking.service_point

    @booking.service_point.active_operators.each do |operator|
      next unless operator.user

      BookingNotificationJob.perform_later(@booking.id, notification_type, operator.user.id.to_s)
    end
  rescue StandardError => e
    log_error "Failed to dispatch operator notifications for booking ##{@booking.id}: #{e.message}"
  end

  # Get admin emails from environment and database.
  # @return [Array<String>]
  def admin_email_list
    admin_list = ENV['ADMIN_NOTIFICATION_EMAILS']&.split(',') || ['admin@tireservice.ua']

    if defined?(Administrator)
      db_admin_emails = User.joins(:administrator)
                           .where(is_active: true, email_verified: true)
                           .where.not(email: nil)
                           .pluck(:email)
      admin_list.concat(db_admin_emails)
    end

    admin_list.compact.uniq
  end
end
