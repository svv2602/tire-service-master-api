# frozen_string_literal: true

# Job to cleanup expired slot reservations
# Should be run frequently (every 1-5 minutes) to release slots promptly
class ExpiredReservationCleanupJob < ApplicationJob
  queue_as :schedules

  # Perform cleanup of expired reservations
  def perform
    Rails.logger.info "[ExpiredReservationCleanupJob] Starting cleanup"

    start_time = Time.current
    expired_count = 0

    # Find and expire all slots with expired reservations
    ScheduleSlot.with_expired_reservations.find_each do |slot|
      if slot.expire_if_timeout!
        expired_count += 1
        Rails.logger.debug "[ExpiredReservationCleanupJob] Expired slot #{slot.id} " \
                           "(was reserved by session: #{slot.reserved_by_session})"
      end
    end

    duration = Time.current - start_time
    Rails.logger.info "[ExpiredReservationCleanupJob] Completed in #{duration.round(2)}s. " \
                      "Expired #{expired_count} reservations"

    # Return count for monitoring
    { expired_count: expired_count, duration: duration }
  end
end
