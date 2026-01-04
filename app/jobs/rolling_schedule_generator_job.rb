# frozen_string_literal: true

# Job to generate schedule slots for upcoming days
# Should be run daily via cron/whenever to ensure slots are always available
class RollingScheduleGeneratorJob < ApplicationJob
  queue_as :schedules

  # Default number of days ahead to generate
  DAYS_AHEAD = 14

  # Generate schedule slots for all active service points
  # @param days_ahead [Integer] number of days to generate (default 14)
  def perform(days_ahead: DAYS_AHEAD)
    Rails.logger.info "[RollingScheduleGeneratorJob] Starting schedule generation for #{days_ahead} days ahead"

    start_time = Time.current
    generated_count = 0
    error_count = 0

    ServicePoint.active.find_each do |service_point|
      begin
        generate_for_service_point(service_point, days_ahead)
        generated_count += 1
      rescue StandardError => e
        error_count += 1
        Rails.logger.error "[RollingScheduleGeneratorJob] Error for service_point #{service_point.id}: #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
      end
    end

    duration = Time.current - start_time
    Rails.logger.info "[RollingScheduleGeneratorJob] Completed in #{duration.round(2)}s. " \
                      "Generated: #{generated_count}, Errors: #{error_count}"
  end

  private

  def generate_for_service_point(service_point, days_ahead)
    start_date = Date.current
    end_date = start_date + days_ahead.days

    (start_date..end_date).each do |date|
      ScheduleManager.generate_slots_for_date(service_point.id, date)
    end

    Rails.logger.debug "[RollingScheduleGeneratorJob] Generated slots for service_point #{service_point.id} " \
                       "from #{start_date} to #{end_date}"
  end
end
