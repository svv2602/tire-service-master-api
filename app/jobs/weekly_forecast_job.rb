# frozen_string_literal: true

# Job for generating weekly AI-enhanced forecasts for all active partners
# Scheduled to run weekly (e.g., every Sunday evening via Sidekiq-Cron)
#
# Generates forecasts with AI insights and sends notifications
# about high-load days to partners
class WeeklyForecastJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info '[WeeklyForecastJob] Starting weekly forecast generation'

    active_partners = Partner.joins(:user).where(users: { is_active: true })
    success_count = 0
    error_count = 0

    active_partners.find_each do |partner|
      generate_partner_forecast(partner)
      success_count += 1
    rescue StandardError => e
      error_count += 1
      Rails.logger.error "[WeeklyForecastJob] Error for partner #{partner.id}: #{e.message}"
    end

    Rails.logger.info "[WeeklyForecastJob] Completed: #{success_count} success, #{error_count} errors"
  end

  private

  def generate_partner_forecast(partner)
    result = ForecastService.new(partner, forecast_days: 7, include_ai: true).call
    return unless result.success?

    # Check for high-load days and notify
    high_load = result.data[:recommendations]&.select { |r| r[:priority] == 'high' }
    if high_load&.any?
      ForecastNotificationJob.perform_later(partner.id)
    end
  end
end
