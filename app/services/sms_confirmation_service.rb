# frozen_string_literal: true

# Service for SMS confirmation of guest bookings.
# Generates a 6-digit code, stores it in Redis with TTL,
# and validates codes for booking confirmation.
class SmsConfirmationService < ApplicationService
  REDIS_KEY_PREFIX = 'sms_code'
  CODE_LENGTH = 6
  CODE_TTL = 10.minutes.to_i # 10 minutes
  MAX_ATTEMPTS = 5
  RESEND_COOLDOWN = 60 # seconds

  # Result structure
  Result = Struct.new(:success, :data, :error, keyword_init: true) do
    def success?
      success
    end
  end

  # --- Class-level convenience methods ---

  # Generate and send an SMS confirmation code for a booking.
  # @param booking [Booking]
  # @return [Result]
  def self.send_code(booking)
    new(booking).send_confirmation_code
  end

  # Verify a submitted code against the stored one.
  # @param booking [Booking]
  # @param code [String]
  # @return [Result]
  def self.verify_code(booking, code)
    new(booking).verify_confirmation_code(code)
  end

  # Check if a booking requires SMS confirmation (guest booking in pending status).
  # @param booking [Booking]
  # @return [Boolean]
  def self.requires_confirmation?(booking)
    booking.guest_booking? && booking.status == 'pending' && !booking.sms_confirmed?
  end

  def initialize(booking)
    @booking = booking
    @phone = booking.service_recipient_phone
  end

  # Generate a code, store it in Redis, and send via SMS.
  # @return [Result]
  def send_confirmation_code
    return Result.new(success: false, error: 'Phone number is missing') unless @phone.present?

    # Check resend cooldown
    if resend_on_cooldown?
      ttl = redis.ttl(cooldown_key)
      return Result.new(success: false, error: 'resend_cooldown', data: { retry_after: ttl })
    end

    code = generate_code
    store_code(code)
    set_resend_cooldown

    # Send SMS
    sms_result = SmsService.send_sms(
      @phone,
      "Kod pidtverdzhennya zapysu v Tire Service: #{code}. Diysnyi 10 khvylyn."
    )

    if sms_result[:success]
      log_info "SMS confirmation code sent for booking #{@booking.id}"
      Result.new(success: true, data: { message: 'Code sent', expires_in: CODE_TTL })
    else
      log_error "Failed to send SMS for booking #{@booking.id}: #{sms_result[:error]}"
      Result.new(success: false, error: sms_result[:error])
    end
  end

  # Verify the submitted code.
  # @param code [String]
  # @return [Result]
  def verify_confirmation_code(code)
    return Result.new(success: false, error: 'Code is required') unless code.present?

    # Check max attempts
    attempts = current_attempts
    if attempts >= MAX_ATTEMPTS
      log_info "Max attempts reached for booking #{@booking.id}"
      return Result.new(success: false, error: 'max_attempts_exceeded')
    end

    stored_code = redis.get(code_key)

    unless stored_code.present?
      return Result.new(success: false, error: 'code_expired')
    end

    increment_attempts

    if stored_code == code.to_s.strip
      # Code is valid — mark booking as SMS confirmed
      @booking.update_column(:sms_confirmed, true)

      # Clean up Redis keys
      redis.del(code_key)
      redis.del(attempts_key)
      redis.del(cooldown_key)

      log_info "SMS code verified for booking #{@booking.id}"
      Result.new(success: true, data: { confirmed: true })
    else
      remaining = MAX_ATTEMPTS - current_attempts
      log_info "Invalid SMS code for booking #{@booking.id}, #{remaining} attempts remaining"
      Result.new(success: false, error: 'invalid_code', data: { remaining_attempts: remaining })
    end
  end

  private

  def generate_code
    SecureRandom.random_number(10**CODE_LENGTH).to_s.rjust(CODE_LENGTH, '0')
  end

  def store_code(code)
    redis.setex(code_key, CODE_TTL, code)
    # Reset attempts counter
    redis.del(attempts_key)
  end

  def set_resend_cooldown
    redis.setex(cooldown_key, RESEND_COOLDOWN, '1')
  end

  def resend_on_cooldown?
    redis.exists?(cooldown_key)
  end

  def current_attempts
    redis.get(attempts_key).to_i
  end

  def increment_attempts
    redis.incr(attempts_key)
    # Set TTL on attempts key matching the code TTL
    redis.expire(attempts_key, CODE_TTL) if current_attempts == 1
  end

  # Redis key for the confirmation code
  def code_key
    "#{REDIS_KEY_PREFIX}:#{@phone}:#{@booking.id}"
  end

  # Redis key for tracking verification attempts
  def attempts_key
    "#{REDIS_KEY_PREFIX}:attempts:#{@phone}:#{@booking.id}"
  end

  # Redis key for resend cooldown
  def cooldown_key
    "#{REDIS_KEY_PREFIX}:cooldown:#{@phone}:#{@booking.id}"
  end

  def redis
    @redis ||= Redis.current
  end
end
