# frozen_string_literal: true

# Concern for integrating Booking with ScheduleSlot system
# Handles slot reservation, validation, and duration calculation
module BookingSlotIntegration
  extend ActiveSupport::Concern

  included do
    # Associations
    belongs_to :service_post, optional: true

    # Validations
    validate :validate_slot_availability, on: :create, unless: -> { skip_availability_check }
    validate :validate_services_fit_in_duration, on: :create

    # Callbacks
    before_validation :calculate_duration_from_services, on: :create
    before_create :reserve_slots_for_booking
    after_destroy :release_reserved_slots
    after_update :handle_slot_changes, if: :booking_time_changed?

    # Scopes
    scope :with_reserved_slots, -> { where.not(reserved_slot_ids: []) }
    scope :for_service_post, ->(post_id) { where(service_post_id: post_id) }
  end

  # ==================== DURATION CALCULATION ====================

  # Calculate total duration based on selected services
  # @return [Integer] duration in minutes
  def calculate_total_duration
    return calculated_duration_minutes if calculated_duration_minutes.present?

    car_type_name = car_type&.name || 'sedan'

    total = services.sum do |service|
      service.duration_for_car_type(car_type_name)
    end

    # Default minimum duration if no services
    total.positive? ? total : 30
  end

  # Recalculate and update duration
  def recalculate_duration!
    self.calculated_duration_minutes = calculate_total_duration
    save!
  end

  # ==================== SLOT MANAGEMENT ====================

  # Get reserved slots for this booking
  # @return [ActiveRecord::Relation]
  def reserved_slots
    return ScheduleSlot.none if reserved_slot_ids.blank?

    ScheduleSlot.where(id: reserved_slot_ids)
  end

  # Check if booking has reserved slots
  def has_reserved_slots?
    reserved_slot_ids.present? && reserved_slot_ids.any?
  end

  # Find available slots for this booking
  # @return [Array<Hash>] available time windows
  def find_available_slots
    return [] unless service_point_id && booking_date

    duration = calculate_total_duration
    options = {}
    options[:start_time] = start_time if start_time.present?

    ScheduleManager.find_available_slots_for_duration(
      service_point_id,
      booking_date,
      duration,
      options
    )
  end

  # Reserve slots from session reservation
  # @param session_id [String] session that has the reservation
  # @return [Boolean] success
  def reserve_slots_from_session(session_id)
    slots = ScheduleManager.get_slots_for_session(session_id)
    return false if slots.empty?

    # Verify slots are for same service point and date
    return false unless slots.all? { |s| s.service_point_id == service_point_id && s.slot_date == booking_date }

    # Confirm reservation
    result = ScheduleManager.confirm_reservation(session_id, slots.map(&:id))
    return false unless result[:success]

    # Update booking with slot info
    self.reserved_slot_ids = slots.map(&:id)
    self.service_post_id = slots.first.service_post_id
    self.booking_session_id = session_id

    # Set times from slots
    sorted_slots = slots.sort_by(&:start_time)
    self.start_time = sorted_slots.first.start_time
    self.end_time = sorted_slots.last.end_time

    true
  end

  # Release all reserved slots
  def release_all_slots
    return unless has_reserved_slots?

    reserved_slots.each do |slot|
      slot.update(
        reservation_status: 'available',
        reserved_at: nil,
        reserved_until: nil,
        reserved_by_session: nil
      )
    end

    self.reserved_slot_ids = []
  end

  # ==================== AVAILABILITY CHECKS ====================

  # Check if the booking time slot is available
  # @return [Boolean]
  def slot_available?
    return false unless service_point_id && booking_date && start_time

    duration = calculate_total_duration
    options = { start_time: start_time }

    available_windows = ScheduleManager.find_available_slots_for_duration(
      service_point_id,
      booking_date,
      duration,
      options
    )

    # Check if any window matches our start time
    available_windows.any? do |window|
      window[:start_time].strftime('%H:%M') == start_time_formatted
    end
  end

  # Check if services fit in the available time
  # @return [Boolean]
  def services_fit_in_slot?
    return true unless end_time.present? && services.any?

    required_duration = calculate_total_duration
    available_duration = total_duration_minutes

    required_duration <= available_duration
  end

  private

  # ==================== VALIDATION METHODS ====================

  def validate_slot_availability
    return if is_service_booking # Skip for service bookings

    unless slot_available?
      errors.add(:start_time, I18n.t('bookings.errors.slot_not_available',
        default: 'Selected time slot is not available'))
    end
  end

  def validate_services_fit_in_duration
    return if services.empty?
    return unless end_time.present?

    unless services_fit_in_slot?
      required = calculate_total_duration
      available = total_duration_minutes

      errors.add(:services, I18n.t('bookings.errors.services_dont_fit',
        required: required, available: available,
        default: "Selected services require #{required} minutes, but only #{available} minutes available"))
    end
  end

  # ==================== CALLBACK METHODS ====================

  def calculate_duration_from_services
    return if calculated_duration_minutes.present?

    self.calculated_duration_minutes = calculate_total_duration

    # Auto-set end_time if not provided
    if start_time.present? && end_time.blank? && calculated_duration_minutes.positive?
      self.end_time = calculate_end_time
    end
  end

  def reserve_slots_for_booking
    return if is_service_booking # Skip for service bookings
    return if reserved_slot_ids.present? # Already reserved from session

    # Try to find and reserve slots
    duration = calculated_duration_minutes || calculate_total_duration
    options = {}
    options[:post_id] = service_post_id if service_post_id.present?

    available_windows = ScheduleManager.find_available_slots_for_duration(
      service_point_id,
      booking_date,
      duration,
      options
    )

    # Find window matching our start time
    matching_window = available_windows.find do |window|
      window[:start_time].strftime('%H:%M') == start_time_formatted
    end

    return unless matching_window

    # Generate a session ID for this booking
    session_id = "booking_#{SecureRandom.uuid}"

    # Reserve the slots
    result = ScheduleManager.reserve_multiple_slots(
      session_id,
      matching_window[:slot_ids],
      timeout_minutes: 30 # Longer timeout for booking process
    )

    if result[:success]
      # Confirm immediately since we're creating the booking
      ScheduleManager.confirm_reservation(session_id, matching_window[:slot_ids])

      self.reserved_slot_ids = matching_window[:slot_ids]
      self.service_post_id = matching_window[:post_id]
      self.booking_session_id = session_id
    end
  end

  def release_reserved_slots
    release_all_slots
  end

  def handle_slot_changes
    # If time/date changed, need to re-reserve slots
    return unless saved_change_to_booking_date? || saved_change_to_start_time?

    # Release old slots
    release_all_slots

    # Reserve new slots
    reserve_slots_for_booking
    save if reserved_slot_ids_changed?
  end

  def booking_time_changed?
    saved_change_to_booking_date? || saved_change_to_start_time?
  end

  # ==================== HELPER METHODS ====================

  def start_time_formatted
    if start_time.is_a?(String)
      start_time
    else
      start_time.strftime('%H:%M')
    end
  end

  def calculate_end_time
    return nil unless start_time.present? && calculated_duration_minutes.present?

    base_time = if start_time.is_a?(String)
      Time.parse("#{booking_date} #{start_time}")
    else
      Time.parse("#{booking_date} #{start_time.strftime('%H:%M')}")
    end

    end_datetime = base_time + calculated_duration_minutes.minutes
    end_datetime.strftime('%H:%M')
  end
end
