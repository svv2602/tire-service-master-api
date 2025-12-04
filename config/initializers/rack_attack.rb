# frozen_string_literal: true

# Rack::Attack configuration for rate limiting and brute-force protection
class Rack::Attack
  # Use Redis for caching if available, otherwise use memory store
  if Rails.env.production? && ENV["REDIS_URL"]
    Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: ENV["REDIS_URL"])
  else
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  # Safelist localhost in development and test environments
  safelist("allow-localhost") do |req|
    Rails.env.development? || Rails.env.test? && req.ip == "127.0.0.1"
  end

  # Login throttle: 5 requests per minute per IP
  throttle("login/ip", limit: 5, period: 1.minute) do |req|
    if req.path == "/api/v1/auth/login" && req.post?
      req.ip
    end
  end

  # Login throttle: 5 requests per minute per login (email)
  throttle("login/email", limit: 5, period: 1.minute) do |req|
    if req.path == "/api/v1/auth/login" && req.post?
      begin
        body = JSON.parse(req.body.read)
        req.body.rewind
        body["email"]&.downcase&.strip
      rescue JSON::ParserError
        nil
      end
    end
  end

  # Password reset throttle: 3 requests per 5 minutes per IP
  throttle("password_reset/ip", limit: 3, period: 5.minutes) do |req|
    if req.path == "/api/v1/auth/password_reset" && req.post?
      req.ip
    end
  end

  # Registration throttle: 3 requests per minute per IP
  throttle("registration/ip", limit: 3, period: 1.minute) do |req|
    if req.path == "/api/v1/auth/register" && req.post?
      req.ip
    end
  end

  # Tire chat throttle: 10 requests per minute per IP
  throttle("tire_chat/ip", limit: 10, period: 1.minute) do |req|
    if req.path.start_with?("/api/v1/tire_chat") && req.post?
      req.ip
    end
  end

  # General API throttle: 300 requests per minute per IP
  throttle("api/ip", limit: 300, period: 1.minute) do |req|
    if req.path.start_with?("/api/")
      req.ip
    end
  end

  # Fail2ban: Block IPs with excessive failed login attempts
  # Ban for 1 hour after 10 failed attempts within 1 minute
  blocklist("fail2ban/login") do |req|
    Rack::Attack::Allow2Ban.filter(req.ip, maxretry: 10, findtime: 1.minute, bantime: 1.hour) do
      req.path == "/api/v1/auth/login" && req.post?
    end
  end

  # Custom response for throttled requests (429 Too Many Requests)
  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"]
    now = match_data[:epoch_time]
    retry_after = match_data[:period] - (now % match_data[:period])

    [
      429,
      {
        "Content-Type" => "application/json",
        "Retry-After" => retry_after.to_s
      },
      [{
        error: "Too Many Requests",
        message: "Rate limit exceeded. Please retry after #{retry_after} seconds.",
        retry_after: retry_after
      }.to_json]
    ]
  end

  # Custom response for blocklisted requests (403 Forbidden)
  self.blocklisted_responder = lambda do |request|
    [
      403,
      { "Content-Type" => "application/json" },
      [{
        error: "Forbidden",
        message: "Your IP has been temporarily blocked due to suspicious activity. Please try again later."
      }.to_json]
    ]
  end
end

# Log throttled and blocked requests
ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _id, payload|
  req = payload[:request]
  Rails.logger.warn(
    "[Rack::Attack] Throttled request: " \
    "IP=#{req.ip} Path=#{req.path} " \
    "Match=#{req.env['rack.attack.matched']}"
  )
end

ActiveSupport::Notifications.subscribe("blocklist.rack_attack") do |_name, _start, _finish, _id, payload|
  req = payload[:request]
  Rails.logger.error(
    "[Rack::Attack] Blocked request: " \
    "IP=#{req.ip} Path=#{req.path} " \
    "Match=#{req.env['rack.attack.matched']}"
  )
end
