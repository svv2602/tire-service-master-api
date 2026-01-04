# frozen_string_literal: true

# Job for sending review request notifications after completed bookings
class ReviewRequestJob < ApplicationJob
  queue_as :default

  # Send review request for a specific booking
  def perform(booking_id = nil, options = {})
    if booking_id
      send_review_request_for_booking(booking_id)
    else
      send_scheduled_review_requests(options)
    end
  end

  private

  # Send review request for a specific booking
  def send_review_request_for_booking(booking_id)
    booking = Booking.find_by(id: booking_id)
    return unless booking
    return unless can_request_review?(booking)

    send_review_request(booking)
  end

  # Send scheduled review requests for all eligible bookings
  def send_scheduled_review_requests(options)
    delay_hours = options[:delay_hours] || default_delay_hours

    # Find completed bookings that need review requests
    eligible_bookings = Booking
                          .where(status: 'completed')
                          .where(review_request_sent_at: nil)
                          .where('updated_at <= ?', delay_hours.hours.ago)
                          .includes(:review, :service_point, client: :user)

    eligible_bookings.find_each do |booking|
      next unless can_request_review?(booking)

      send_review_request(booking)
    end
  end

  def can_request_review?(booking)
    # Skip if not completed
    return false unless booking.status == 'completed'

    # Skip if review request already sent
    return false if booking.review_request_sent_at.present?

    # Skip if review already exists
    return false if booking.review.present?

    # Skip if booking is too old (more than 14 days)
    return false if booking.booking_date < 14.days.ago

    # Skip if no contact information
    return false unless booking.service_recipient_phone.present? || booking.service_recipient_email.present?

    # Check service point settings
    service_point = booking.service_point
    return false unless service_point

    # Check if review requests are enabled for this service point
    settings = service_point.review_request_settings
    return true if settings.nil? # Default: enabled

    settings['enabled'] != false
  end

  def send_review_request(booking)
    # Generate unique review token
    token = generate_review_token(booking)

    # Build review URL
    review_url = build_review_url(booking, token)

    # Send via SMS
    if booking.service_recipient_phone.present?
      send_sms_review_request(booking, review_url)
    end

    # Send via Email
    if booking.service_recipient_email.present?
      send_email_review_request(booking, review_url)
    end

    # Mark as sent
    booking.update_column(:review_request_sent_at, Time.current)

    # Track in review request log
    create_review_request_log(booking, token)

    Rails.logger.info "Review request sent for booking #{booking.id}"
  rescue StandardError => e
    Rails.logger.error "Failed to send review request for booking #{booking.id}: #{e.message}"
  end

  def generate_review_token(booking)
    # Generate a unique, URL-safe token
    loop do
      token = SecureRandom.urlsafe_base64(16)
      # Check if token is unique
      break token unless ReviewRequestToken.exists?(token: token)
    end
  end

  def build_review_url(booking, token)
    # Store the token
    ReviewRequestToken.create!(
      token: token,
      booking_id: booking.id,
      expires_at: 30.days.from_now
    ) if defined?(ReviewRequestToken)

    # Build URL
    base_url = ENV['FRONTEND_URL'] || 'https://tireservice.ua'
    "#{base_url}/review/#{token}"
  end

  def send_sms_review_request(booking, review_url)
    return unless defined?(SmsService)

    phone = booking.service_recipient_phone
    service_point_name = booking.service_point&.name || 'СТО'

    message = build_sms_message(service_point_name, review_url)

    SmsService.send_message(phone, message)
    Rails.logger.info "SMS review request sent to #{phone} for booking #{booking.id}"
  rescue StandardError => e
    Rails.logger.error "Failed to send SMS review request: #{e.message}"
  end

  def send_email_review_request(booking, review_url)
    return unless defined?(ReviewRequestMailer)

    ReviewRequestMailer.review_request(booking, review_url).deliver_later
    Rails.logger.info "Email review request sent to #{booking.service_recipient_email} for booking #{booking.id}"
  rescue StandardError => e
    Rails.logger.error "Failed to send email review request: #{e.message}"
  end

  def build_sms_message(service_point_name, review_url)
    # Use I18n if available
    if defined?(I18n)
      I18n.t(
        'reviews.request_sms',
        service_point: service_point_name,
        url: review_url,
        default: "Дякуємо за візит до #{service_point_name}! Будь ласка, залиште відгук: #{review_url}"
      )
    else
      "Дякуємо за візит до #{service_point_name}! Будь ласка, залиште відгук: #{review_url}"
    end
  end

  def create_review_request_log(booking, token)
    return unless defined?(ReviewRequestLog)

    ReviewRequestLog.create(
      booking_id: booking.id,
      service_point_id: booking.service_point_id,
      client_id: booking.client_id,
      token: token,
      sent_at: Time.current,
      sent_via: determine_sent_via(booking)
    )
  rescue StandardError => e
    Rails.logger.error "Failed to create review request log: #{e.message}"
  end

  def determine_sent_via(booking)
    channels = []
    channels << 'sms' if booking.service_recipient_phone.present?
    channels << 'email' if booking.service_recipient_email.present?
    channels.join(',')
  end

  def default_delay_hours
    # Get from settings or use default (24 hours)
    ENV.fetch('REVIEW_REQUEST_DELAY_HOURS', 24).to_i
  end
end
