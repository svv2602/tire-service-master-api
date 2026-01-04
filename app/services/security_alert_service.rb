# frozen_string_literal: true

# SecurityAlertService - centralized service for security monitoring and alerts
# Integrates with Rack::Attack, audit logging, and notification systems
class SecurityAlertService
  # Threshold for triggering alerts
  THRESHOLDS = {
    failed_logins_per_ip: 10,      # Failed logins from same IP
    failed_logins_per_email: 5,    # Failed logins for same email
    blocks_per_ip: 3,              # Rack::Attack blocks from same IP
    throttles_per_ip: 10           # Rack::Attack throttles from same IP
  }.freeze

  # Time windows for counting events
  TIME_WINDOWS = {
    failed_logins: 1.hour,
    blocks: 1.hour,
    throttles: 15.minutes
  }.freeze

  class << self
    # Record a Rack::Attack throttle event
    # @param request [Rack::Request] The throttled request
    # @param matched [String] The throttle rule that matched
    def record_throttle(request, matched)
      ip = request.ip
      path = request.path
      cache_key = "security:throttle:#{ip}"

      # Increment throttle count for this IP
      count = increment_counter(cache_key, TIME_WINDOWS[:throttles])

      # Log to Rails logger
      Rails.logger.warn "[Security] Throttled: IP=#{ip} Path=#{path} Rule=#{matched} Count=#{count}"

      # Log to audit system if available
      log_security_event(
        event_type: 'throttle',
        ip_address: ip,
        path: path,
        rule: matched,
        count: count
      )

      # Send alert if threshold exceeded
      if count >= THRESHOLDS[:throttles_per_ip]
        send_throttle_alert(ip, path, matched, count)
      end
    end

    # Record a Rack::Attack block event
    # @param request [Rack::Request] The blocked request
    # @param matched [String] The block rule that matched
    def record_block(request, matched)
      ip = request.ip
      path = request.path
      cache_key = "security:block:#{ip}"

      # Increment block count for this IP
      count = increment_counter(cache_key, TIME_WINDOWS[:blocks])

      # Log to Rails logger (error level for blocks)
      Rails.logger.error "[Security] Blocked: IP=#{ip} Path=#{path} Rule=#{matched} Count=#{count}"

      # Log to audit system
      log_security_event(
        event_type: 'block',
        ip_address: ip,
        path: path,
        rule: matched,
        count: count,
        severity: 'high'
      )

      # Always send alert for blocks (they're already severe)
      if count >= THRESHOLDS[:blocks_per_ip]
        send_block_alert(ip, path, matched, count)
      end
    end

    # Record a failed login attempt
    # @param ip [String] IP address
    # @param email [String] Email attempted
    # @param reason [String] Reason for failure
    def record_failed_login(ip:, email: nil, reason: 'invalid_credentials')
      ip_cache_key = "security:failed_login:ip:#{ip}"
      ip_count = increment_counter(ip_cache_key, TIME_WINDOWS[:failed_logins])

      email_count = 0
      if email.present?
        email_cache_key = "security:failed_login:email:#{email.downcase}"
        email_count = increment_counter(email_cache_key, TIME_WINDOWS[:failed_logins])
      end

      # Log to Rails logger
      Rails.logger.warn "[Security] Failed login: IP=#{ip} Email=#{email} Reason=#{reason} IP_Count=#{ip_count}"

      # Log to audit system
      log_security_event(
        event_type: 'failed_login',
        ip_address: ip,
        email: email,
        reason: reason,
        ip_count: ip_count,
        email_count: email_count
      )

      # Send alerts if thresholds exceeded
      if ip_count >= THRESHOLDS[:failed_logins_per_ip]
        SecurityAlertJob.perform_later(
          'frequent_failed_logins',
          ip_address: ip,
          attempts_count: ip_count,
          time_window: "#{TIME_WINDOWS[:failed_logins].to_i / 60} минут"
        )
      end

      if email.present? && email_count >= THRESHOLDS[:failed_logins_per_email]
        SecurityAlertJob.perform_later(
          'suspicious_user_behavior',
          behavior_type: 'multiple_failed_logins',
          severity: 'high',
          details: {
            email: email,
            attempts_count: email_count,
            last_ip: ip
          }
        )
      end
    end

    # Record successful login (to track multiple IP access)
    # @param user [User] The user who logged in
    # @param ip [String] IP address
    def record_successful_login(user:, ip:)
      return unless user.present?

      # Track IPs for this user
      cache_key = "security:user_ips:#{user.id}"
      ips = Rails.cache.read(cache_key) || []
      ips << ip unless ips.include?(ip)
      ips = ips.last(10) # Keep only last 10 IPs
      Rails.cache.write(cache_key, ips, expires_in: 24.hours)

      # Check for suspicious multiple IP access
      if ips.size >= 5
        SecurityAlertJob.perform_later(
          'multiple_ip_access',
          user: user,
          ip_addresses: ips,
          time_window: '24 часа'
        )
      end

      Rails.logger.info "[Security] Successful login: User=#{user.id} IP=#{ip} Total_IPs=#{ips.size}"
    end

    # Get security statistics for monitoring
    # @return [Hash] Current security statistics
    def stats
      {
        timestamp: Time.current.iso8601,
        counters: get_all_counters
      }
    end

    private

    # Increment a counter in cache
    def increment_counter(key, expires_in)
      current = Rails.cache.read(key).to_i
      new_value = current + 1
      Rails.cache.write(key, new_value, expires_in: expires_in)
      new_value
    end

    # Log security event to audit system
    def log_security_event(event_type:, **data)
      return unless defined?(SystemLog)

      SystemLog.create(
        action: "security_#{event_type}",
        resource_type: 'Security',
        new_value: data.merge(timestamp: Time.current),
        ip_address: data[:ip_address]
      )
    rescue StandardError => e
      Rails.logger.error "[Security] Failed to log security event: #{e.message}"
    end

    # Send throttle alert
    def send_throttle_alert(ip, path, matched, count)
      Rails.logger.warn "[Security] ALERT: High throttle count for IP=#{ip} Count=#{count}"

      # Send via Telegram if configured
      send_telegram_alert(
        "⚠️ *Rate Limiting Alert*\n\n" \
        "IP: `#{ip}`\n" \
        "Path: `#{path}`\n" \
        "Rule: `#{matched}`\n" \
        "Count: #{count} in #{TIME_WINDOWS[:throttles].to_i / 60} min"
      )
    end

    # Send block alert
    def send_block_alert(ip, path, matched, count)
      Rails.logger.error "[Security] ALERT: IP blocked - IP=#{ip} Count=#{count}"

      # Send via Telegram if configured
      send_telegram_alert(
        "🚫 *IP Blocked Alert*\n\n" \
        "IP: `#{ip}`\n" \
        "Path: `#{path}`\n" \
        "Rule: `#{matched}`\n" \
        "Block Count: #{count} in #{TIME_WINDOWS[:blocks].to_i / 60} min"
      )
    end

    # Send alert via Telegram
    def send_telegram_alert(message)
      return unless ENV['TELEGRAM_BOT_TOKEN'] && ENV['TELEGRAM_ADMIN_CHAT_ID']

      TelegramService.send_message(
        chat_id: ENV['TELEGRAM_ADMIN_CHAT_ID'],
        text: message,
        parse_mode: 'Markdown'
      )
    rescue StandardError => e
      Rails.logger.error "[Security] Failed to send Telegram alert: #{e.message}"
    end

    # Get all security counters for monitoring
    def get_all_counters
      # This is a simplified version - in production you'd scan Redis keys
      {
        note: 'Counter data is distributed in cache'
      }
    end
  end
end
