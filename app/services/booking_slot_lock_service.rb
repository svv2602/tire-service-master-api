# frozen_string_literal: true

require 'zlib'

# Service for atomically creating bookings with pessimistic locking to prevent race conditions.
#
# Uses PostgreSQL advisory locks to serialize booking creation for the same
# (service_point_id, booking_date, start_time) combination. This eliminates the
# window of vulnerability between availability check and booking creation.
#
# Usage:
#   result = BookingSlotLockService.call(
#     service_point_id: 1,
#     booking_date: Date.tomorrow,
#     start_time: '10:00',
#     booking_attrs: { ... },
#     skip_availability: false
#   )
#
#   if result.success?
#     booking = result.data[:booking]
#   else
#     # result.error contains the error message
#     # result.data[:error_type] is :slot_taken, :lock_timeout, :validation_error, or :db_conflict
#   end
class BookingSlotLockService < ApplicationService
  # Lock timeout in seconds — how long to wait for the advisory lock
  LOCK_TIMEOUT_SECONDS = 5

  Result = Struct.new(:success, :data, :error, keyword_init: true) do
    def success?
      success
    end
  end

  def initialize(service_point_id:, booking_date:, start_time:, booking_attrs:, skip_availability: false, category_id: nil)
    @service_point_id = service_point_id
    @booking_date = booking_date.is_a?(String) ? Date.parse(booking_date) : booking_date
    @start_time = start_time
    @booking_attrs = booking_attrs
    @skip_availability = skip_availability
    @category_id = category_id
  end

  def call
    create_booking_with_lock
  end

  private

  def create_booking_with_lock
    ActiveRecord::Base.transaction do
      # Acquire advisory lock for this specific slot combination.
      # This serializes all booking attempts for the same service_point + date + time.
      unless acquire_advisory_lock
        return Result.new(
          success: false,
          error: I18n.t('bookings.errors.lock_timeout', default: 'Server is busy, please try again'),
          data: { error_type: :lock_timeout }
        )
      end

      # Re-check availability INSIDE the lock to guarantee consistency
      unless @skip_availability
        availability = check_availability_inside_lock
        unless availability[:available]
          return Result.new(
            success: false,
            error: I18n.t('bookings.errors.slot_taken', default: 'Selected time slot is no longer available'),
            data: { error_type: :slot_taken, reason: availability[:reason] }
          )
        end
      end

      # Create the booking — skip model-level availability check since we just verified
      booking = Booking.new(@booking_attrs)
      booking.skip_availability_check = true

      if booking.save
        Result.new(success: true, data: { booking: booking })
      else
        Result.new(
          success: false,
          error: booking.errors.full_messages.join(', '),
          data: { error_type: :validation_error, errors: booking.errors.full_messages }
        )
      end
    end
  rescue ActiveRecord::RecordNotUnique => e
    # Database-level unique constraint caught a duplicate — this is the last safety net
    Rails.logger.warn "[BookingSlotLockService] RecordNotUnique caught: #{e.message}"
    Result.new(
      success: false,
      error: I18n.t('bookings.errors.slot_taken', default: 'Selected time slot is no longer available'),
      data: { error_type: :db_conflict }
    )
  rescue ActiveRecord::LockWaitTimeout => e
    Rails.logger.warn "[BookingSlotLockService] Lock timeout: #{e.message}"
    Result.new(
      success: false,
      error: I18n.t('bookings.errors.lock_timeout', default: 'Server is busy, please try again'),
      data: { error_type: :lock_timeout }
    )
  end

  # Acquire a PostgreSQL advisory lock scoped to this specific slot.
  # Uses pg_try_advisory_xact_lock which is transaction-scoped (auto-released on commit/rollback).
  # Returns true if lock acquired, false if timeout.
  def acquire_advisory_lock
    lock_key = generate_lock_key
    # pg_try_advisory_xact_lock returns true immediately if the lock is available,
    # false if it's held by another transaction. We retry for LOCK_TIMEOUT_SECONDS.
    deadline = Time.current + LOCK_TIMEOUT_SECONDS

    loop do
      result = ActiveRecord::Base.connection.select_value(
        "SELECT pg_try_advisory_xact_lock(#{lock_key})"
      )
      return true if result

      if Time.current >= deadline
        Rails.logger.warn "[BookingSlotLockService] Advisory lock timeout for key #{lock_key}"
        return false
      end

      sleep(0.05) # 50ms between retries
    end
  end

  # Generate a deterministic lock key from (service_point_id, booking_date, start_time).
  # PostgreSQL advisory locks use bigint keys. We combine the three values into one.
  def generate_lock_key
    # Use a hash to generate a deterministic bigint from our composite key.
    # The hash space is large enough to avoid practical collisions.
    date_int = @booking_date.to_s.delete('-').to_i  # e.g., 20260305
    time_int = @start_time.to_s.gsub(':', '').to_i  # e.g., 1000 for "10:00"

    # Combine into a single bigint (PostgreSQL advisory lock key).
    # Use Zlib.crc32 for a compact, deterministic hash.
    raw = "booking_lock:#{@service_point_id}:#{date_int}:#{time_int}"
    Zlib.crc32(raw).to_i
  end

  # Check availability inside the advisory lock — this is the authoritative check.
  def check_availability_inside_lock
    DynamicAvailabilityService.check_availability_at_time(
      @service_point_id,
      @booking_date,
      Time.parse("#{@booking_date} #{@start_time}"),
      nil, # duration determined by service
      category_id: @category_id
    )
  end
end
