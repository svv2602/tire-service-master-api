# frozen_string_literal: true

# AiBudgetAlertJob - Sends alert when daily AI budget is exceeded
#
# Phase-02: Proactive budget monitoring
# Triggered by AiRequestWrapper when daily spend exceeds threshold
#
class AiBudgetAlertJob < ApplicationJob
  queue_as :default

  def perform
    budget = ENV.fetch('AI_DAILY_BUDGET_USD', '10.0').to_f
    spent = AiUsageLog.todays_cost.round(4)

    Rails.logger.error "[AiBudgetAlertJob] Daily AI budget exceeded! Spent: $#{spent}, Budget: $#{budget}"

    # Notify admin users via notification system if available
    admin_users = User.where(role: 'admin')
    admin_users.find_each do |admin|
      Notification.create(
        user: admin,
        title: 'AI Budget Alert',
        message: "Daily AI spending ($#{spent}) has exceeded the budget ($#{budget}). " \
                 "Date: #{Date.current}. Review usage at /admin/ai-usage.",
        notification_type: 'system_alert',
        priority: 'high'
      )
    rescue StandardError => e
      Rails.logger.warn "[AiBudgetAlertJob] Failed to notify admin #{admin.id}: #{e.message}"
    end
  end
end
