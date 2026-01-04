# frozen_string_literal: true

# Job for sending peak day forecast notifications to partners
class ForecastNotificationJob < ApplicationJob
  queue_as :default

  def perform(partner_id = nil)
    if partner_id
      # Send notification to specific partner
      partner = Partner.find_by(id: partner_id)
      send_notification_to_partner(partner) if partner
    else
      # Send notifications to all partners with enabled notifications
      partners_with_notifications.find_each do |partner|
        send_notification_to_partner(partner)
      end
    end
  end

  private

  def partners_with_notifications
    # Find partners who have enabled peak notifications
    # If the column doesn't exist, notify all active partners
    if Partner.column_names.include?('peak_notification_enabled')
      Partner.where(peak_notification_enabled: true)
    else
      Partner.joins(:user).where(users: { is_active: true })
    end
  end

  def send_notification_to_partner(partner)
    return unless partner&.user

    result = ForecastService.new(partner, forecast_days: 7).call
    return unless result.success?

    recommendations = result.data[:recommendations]
    high_priority = recommendations.select { |r| r[:priority] == 'high' }

    return if high_priority.empty?

    # Send email notification
    send_email_notification(partner, high_priority, result.data[:forecast])

    # Send push notification if available
    send_push_notification(partner, high_priority)

    # Send telegram notification if configured
    send_telegram_notification(partner, high_priority) if partner.telegram_chat_id.present?

    Rails.logger.info "Sent forecast notification to partner #{partner.id}"
  rescue StandardError => e
    Rails.logger.error "Failed to send forecast notification to partner #{partner.id}: #{e.message}"
  end

  def send_email_notification(partner, recommendations, forecast)
    return unless partner.user&.email

    # Build email content
    subject = build_email_subject(recommendations)
    body = build_email_body(recommendations, forecast)

    # Use NotificationService if available
    if defined?(NotificationService)
      NotificationService.send_email(
        to: partner.user.email,
        subject: subject,
        body: body,
        template: 'forecast_notification'
      )
    else
      # Fallback to mailer if defined
      ForecastMailer.peak_notification(partner, recommendations, forecast).deliver_later if defined?(ForecastMailer)
    end
  end

  def send_push_notification(partner, recommendations)
    return unless defined?(PushService)

    first_recommendation = recommendations.first
    return unless first_recommendation

    message = case first_recommendation[:type]
              when 'high_load'
                "High load expected on #{first_recommendation[:date]}. Plan additional staff."
              when 'seasonal_alert'
                'Seasonal peak approaching! Prepare for increased demand.'
              else
                'Check your load forecast for the upcoming week.'
              end

    PushService.send_to_user(
      partner.user,
      title: 'Load Forecast Alert',
      body: message,
      data: { type: 'forecast', url: '/partner/forecasts' }
    )
  end

  def send_telegram_notification(partner, recommendations)
    return unless defined?(TelegramService) && partner.telegram_chat_id.present?

    message = build_telegram_message(recommendations)

    TelegramService.send_message(
      chat_id: partner.telegram_chat_id,
      text: message,
      parse_mode: 'HTML'
    )
  end

  def build_email_subject(recommendations)
    high_load_days = recommendations.select { |r| r[:type] == 'high_load' }

    if high_load_days.any?
      "Load Forecast Alert: High demand expected on #{high_load_days.count} day(s)"
    else
      'Weekly Load Forecast Summary'
    end
  end

  def build_email_body(recommendations, forecast)
    body = []
    body << "Load Forecast for the upcoming week:\n"

    # Add forecast summary
    forecast.each do |day|
      indicator = case day[:load_indicator]
                  when 'busy' then '🔴'
                  when 'medium' then '🟡'
                  else '🟢'
                  end
      body << "#{indicator} #{day[:date]} (#{day[:day_of_week]}): ~#{day[:predicted_bookings]} bookings"
    end

    body << "\n\nRecommendations:"
    recommendations.each do |rec|
      priority_icon = rec[:priority] == 'high' ? '⚠️' : 'ℹ️'
      body << "#{priority_icon} #{rec[:message]}"
      body << "   Suggested operators: #{rec[:suggested_operators]}" if rec[:suggested_operators]
    end

    body.join("\n")
  end

  def build_telegram_message(recommendations)
    lines = ["<b>📊 Load Forecast Alert</b>\n"]

    recommendations.each do |rec|
      priority_emoji = case rec[:priority]
                       when 'high' then '🔴'
                       when 'medium' then '🟡'
                       else '🟢'
                       end

      lines << "#{priority_emoji} <b>#{rec[:type].humanize}</b>"
      lines << rec[:message]
      lines << "📅 Date: #{rec[:date]}" if rec[:date]
      lines << "👷 Suggested staff: #{rec[:suggested_operators]}" if rec[:suggested_operators]
      lines << ''
    end

    lines.join("\n")
  end
end
