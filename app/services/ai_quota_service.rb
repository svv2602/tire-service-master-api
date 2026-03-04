# frozen_string_literal: true

# AiQuotaService - Manages rate limits and quotas for AI API calls
#
# Phase-02: Quota management for controlling AI costs
#
# Quota structure:
#   - Global: MAX_GLOBAL_RPM requests/minute to OpenAI
#   - Per-user tire_search: MAX_USER_SEARCH_RPH requests/hour
#   - Per-user tire_chat: MAX_USER_CHAT_RPH messages/hour
#   - For unauthenticated users: limits by IP address
#
# Redis keys:
#   ai_quota:global:minute          - global per-minute counter
#   ai_quota:user:{id}:tire_search  - per-user search counter
#   ai_quota:user:{id}:tire_chat    - per-user chat counter
#   ai_quota:ip:{ip}:tire_search    - per-IP search counter
#   ai_quota:ip:{ip}:tire_chat      - per-IP chat counter
#
# Returns:
#   { allowed: true/false, remaining: N, limit: M, retry_after: seconds }
#
class AiQuotaService
  # Quota limits (configurable via ENV or defaults)
  MAX_GLOBAL_RPM = ENV.fetch('AI_GLOBAL_RPM', 60).to_i          # requests/minute globally
  MAX_USER_SEARCH_RPH = ENV.fetch('AI_USER_SEARCH_RPH', 30).to_i # search requests/hour per user
  MAX_USER_CHAT_RPH = ENV.fetch('AI_USER_CHAT_RPH', 50).to_i     # chat messages/hour per user
  MAX_IP_SEARCH_RPH = ENV.fetch('AI_IP_SEARCH_RPH', 15).to_i     # search requests/hour per IP
  MAX_IP_CHAT_RPH = ENV.fetch('AI_IP_CHAT_RPH', 25).to_i         # chat messages/hour per IP

  # Redis key prefixes
  KEY_PREFIX = 'ai_quota'

  # TTLs for counters
  GLOBAL_TTL = 60        # 1 minute
  USER_TTL = 3600        # 1 hour
  IP_TTL = 3600          # 1 hour

  class << self
    # Check if a request is allowed and increment counter
    #
    # @param service_name [String] 'tire_search' or 'tire_chat'
    # @param user [User, nil] Authenticated user (nil for anonymous)
    # @param ip_address [String] Client IP address
    # @return [Hash] { allowed: bool, remaining: int, limit: int, retry_after: int|nil }
    def check_and_increment!(service_name:, user: nil, ip_address: nil)
      # Step 1: Check global limit
      global_result = check_global_limit
      return global_result unless global_result[:allowed]

      # Step 2: Check per-user or per-IP limit
      identity_result = if user.present?
                          check_user_limit(user.id, service_name)
                        elsif ip_address.present?
                          check_ip_limit(ip_address, service_name)
                        else
                          { allowed: true, remaining: 999, limit: 999, retry_after: nil }
                        end

      return identity_result unless identity_result[:allowed]

      # Step 3: Increment all counters (request is allowed)
      increment_global_counter
      if user.present?
        increment_user_counter(user.id, service_name)
      elsif ip_address.present?
        increment_ip_counter(ip_address, service_name)
      end

      identity_result
    end

    # Check quota without incrementing (dry run)
    #
    # @param service_name [String] 'tire_search' or 'tire_chat'
    # @param user [User, nil] Authenticated user
    # @param ip_address [String] Client IP address
    # @return [Hash] { allowed: bool, remaining: int, limit: int, retry_after: int|nil }
    def check(service_name:, user: nil, ip_address: nil)
      global_result = check_global_limit
      return global_result unless global_result[:allowed]

      if user.present?
        check_user_limit(user.id, service_name)
      elsif ip_address.present?
        check_ip_limit(ip_address, service_name)
      else
        { allowed: true, remaining: 999, limit: 999, retry_after: nil }
      end
    end

    # Get current usage stats for admin dashboard
    #
    # @return [Hash] Usage statistics
    def usage_stats
      {
        global: {
          current: global_counter_value,
          limit: MAX_GLOBAL_RPM,
          window: '1 minute'
        },
        limits: {
          user_search: { limit: MAX_USER_SEARCH_RPH, window: '1 hour' },
          user_chat: { limit: MAX_USER_CHAT_RPH, window: '1 hour' },
          ip_search: { limit: MAX_IP_SEARCH_RPH, window: '1 hour' },
          ip_chat: { limit: MAX_IP_CHAT_RPH, window: '1 hour' }
        }
      }
    end

    # Get current usage for a specific user
    #
    # @param user_id [Integer] User ID
    # @return [Hash] Per-service usage
    def user_usage(user_id)
      {
        tire_search: {
          current: read_counter(user_key(user_id, 'tire_search')),
          limit: MAX_USER_SEARCH_RPH,
          remaining: [MAX_USER_SEARCH_RPH - read_counter(user_key(user_id, 'tire_search')), 0].max
        },
        tire_chat: {
          current: read_counter(user_key(user_id, 'tire_chat')),
          limit: MAX_USER_CHAT_RPH,
          remaining: [MAX_USER_CHAT_RPH - read_counter(user_key(user_id, 'tire_chat')), 0].max
        }
      }
    end

    # Reset quota for a user (admin action)
    #
    # @param user_id [Integer] User ID
    def reset_user_quota!(user_id)
      redis.del(user_key(user_id, 'tire_search'))
      redis.del(user_key(user_id, 'tire_chat'))
      Rails.logger.info "[AiQuotaService] Reset quota for user #{user_id}"
    end

    private

    def redis
      @redis ||= Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'))
    end

    # === Global limit ===

    def global_key
      "#{KEY_PREFIX}:global:minute"
    end

    def global_counter_value
      read_counter(global_key)
    end

    def check_global_limit
      current = global_counter_value
      if current >= MAX_GLOBAL_RPM
        ttl = redis.ttl(global_key)
        retry_after = ttl > 0 ? ttl : GLOBAL_TTL
        {
          allowed: false,
          remaining: 0,
          limit: MAX_GLOBAL_RPM,
          retry_after: retry_after,
          reason: 'global_rate_limit'
        }
      else
        {
          allowed: true,
          remaining: MAX_GLOBAL_RPM - current,
          limit: MAX_GLOBAL_RPM,
          retry_after: nil
        }
      end
    end

    def increment_global_counter
      key = global_key
      redis.multi do |multi|
        multi.incr(key)
        multi.expire(key, GLOBAL_TTL)
      end
    end

    # === Per-user limit ===

    def user_key(user_id, service_name)
      "#{KEY_PREFIX}:user:#{user_id}:#{service_name}"
    end

    def limit_for_user_service(service_name)
      case service_name.to_s
      when 'tire_search' then MAX_USER_SEARCH_RPH
      when 'tire_chat' then MAX_USER_CHAT_RPH
      else MAX_USER_SEARCH_RPH
      end
    end

    def check_user_limit(user_id, service_name)
      key = user_key(user_id, service_name)
      limit = limit_for_user_service(service_name)
      current = read_counter(key)

      if current >= limit
        ttl = redis.ttl(key)
        retry_after = ttl > 0 ? ttl : USER_TTL
        {
          allowed: false,
          remaining: 0,
          limit: limit,
          retry_after: retry_after,
          reason: 'user_rate_limit'
        }
      else
        {
          allowed: true,
          remaining: limit - current,
          limit: limit,
          retry_after: nil
        }
      end
    end

    def increment_user_counter(user_id, service_name)
      key = user_key(user_id, service_name)
      redis.multi do |multi|
        multi.incr(key)
        multi.expire(key, USER_TTL)
      end
    end

    # === Per-IP limit ===

    def ip_key(ip_address, service_name)
      "#{KEY_PREFIX}:ip:#{ip_address}:#{service_name}"
    end

    def limit_for_ip_service(service_name)
      case service_name.to_s
      when 'tire_search' then MAX_IP_SEARCH_RPH
      when 'tire_chat' then MAX_IP_CHAT_RPH
      else MAX_IP_SEARCH_RPH
      end
    end

    def check_ip_limit(ip_address, service_name)
      key = ip_key(ip_address, service_name)
      limit = limit_for_ip_service(service_name)
      current = read_counter(key)

      if current >= limit
        ttl = redis.ttl(key)
        retry_after = ttl > 0 ? ttl : IP_TTL
        {
          allowed: false,
          remaining: 0,
          limit: limit,
          retry_after: retry_after,
          reason: 'ip_rate_limit'
        }
      else
        {
          allowed: true,
          remaining: limit - current,
          limit: limit,
          retry_after: nil
        }
      end
    end

    def increment_ip_counter(ip_address, service_name)
      key = ip_key(ip_address, service_name)
      redis.multi do |multi|
        multi.incr(key)
        multi.expire(key, IP_TTL)
      end
    end

    # === Helpers ===

    def read_counter(key)
      redis.get(key).to_i
    rescue Redis::BaseError => e
      Rails.logger.warn "[AiQuotaService] Redis read error: #{e.message}"
      0
    end
  end
end
