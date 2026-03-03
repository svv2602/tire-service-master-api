# frozen_string_literal: true

# AdminNotificationMailer - sends admin alert emails
# Used by AdminNotificationService for critical event notifications.
class AdminNotificationMailer < ApplicationMailer
  default from: Rails.application.credentials.dig(:email, :from) || 'alerts@tire-service.com'

  # Generic admin alert email
  #
  # @param email [String] recipient email
  # @param subject [String] email subject line
  # @param body [String] plain-text message body
  def admin_alert(email:, subject:, body:)
    @body = body
    @timestamp = Time.current

    mail(
      to: email,
      subject: "[Tire Service Admin] #{subject}"
    )
  end
end
