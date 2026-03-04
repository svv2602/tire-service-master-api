# frozen_string_literal: true

# Redis-based token blacklist for JWT revocation.
# Tokens are stored with a TTL matching their remaining lifetime
# so they are automatically cleaned up when they expire.
class TokenBlacklistService
  BLACKLIST_PREFIX = 'token_blacklist:'

  class << self
    # Revoke a token by adding it to the blacklist.
    # The token is stored with a TTL equal to its remaining lifetime.
    # Uses the jti claim from the JWT payload when available,
    # otherwise falls back to a SHA256 digest of the raw token.
    # @param token [String] the raw JWT string
    def revoke(token)
      return if token.blank?

      begin
        # Decode without raising on expiry so we can get the exp and jti claims
        decoded = JWT.decode(
          token,
          Auth::JsonWebToken.secret_key,
          true,
          algorithm: 'HS256',
          verify_expiration: false
        ).first

        exp = decoded['exp'].to_i
        ttl = exp - Time.current.to_i

        # Only blacklist if the token hasn't already expired
        if ttl > 0
          identifier = extract_identifier(decoded, token)
          redis.setex(cache_key(identifier), ttl, '1')
          Rails.logger.debug "TokenBlacklist: revoked token (jti=#{decoded['jti'] || 'none'}), ttl=#{ttl}s"
        end
      rescue JWT::DecodeError => e
        Rails.logger.warn "TokenBlacklist: failed to decode token for revocation: #{e.message}"
      end
    end

    # Check whether a token has been revoked.
    # Checks both jti-based and hash-based identifiers for backward compatibility.
    # @param token [String] the raw JWT string
    # @return [Boolean]
    def revoked?(token)
      return false if token.blank?

      # Try to decode and check by jti first
      begin
        decoded = JWT.decode(
          token,
          Auth::JsonWebToken.secret_key,
          true,
          algorithm: 'HS256',
          verify_expiration: false
        ).first

        identifier = extract_identifier(decoded, token)
        return true if redis.exists?(cache_key(identifier))

        # Backward compatibility: also check the hash-based identifier
        # if the token has a jti but was revoked before jti support
        if decoded['jti'].present?
          fallback_id = token_hash(token)
          return redis.exists?(cache_key(fallback_id))
        end
      rescue JWT::DecodeError
        # If we cannot decode, fall back to hash-based check
        fallback_id = token_hash(token)
        return redis.exists?(cache_key(fallback_id))
      end

      false
    end

    # Revoke all tokens for a specific user by storing a "revoke before" timestamp.
    # Any token issued before this timestamp will be considered revoked.
    # @param user_id [Integer]
    # @param ttl [Integer] how long to keep the marker (default: 30 days, matching refresh token lifetime)
    def revoke_all_for_user(user_id, ttl: 30.days.to_i)
      redis.setex(user_revoke_key(user_id), ttl, Time.current.to_i.to_s)
      Rails.logger.debug "TokenBlacklist: revoked all tokens for user_id=#{user_id}"
    end

    # Check whether a user's tokens have been bulk-revoked.
    # @param user_id [Integer]
    # @param issued_at [Integer] the iat claim from the token
    # @return [Boolean]
    def user_tokens_revoked?(user_id, issued_at)
      revoked_before = redis.get(user_revoke_key(user_id))
      return false if revoked_before.nil?

      issued_at.to_i <= revoked_before.to_i
    end

    private

    # Extract the best available identifier from a decoded token.
    # Prefers the jti claim; falls back to a SHA256 hash of the raw token.
    # @param decoded [Hash] the decoded JWT payload
    # @param token [String] the raw JWT string
    # @return [String]
    def extract_identifier(decoded, token)
      decoded['jti'].presence || token_hash(token)
    end

    # Use a SHA256 digest of the token as the identifier (avoids storing full tokens in Redis)
    def token_hash(token)
      Digest::SHA256.hexdigest(token)
    end

    def cache_key(jti)
      "#{BLACKLIST_PREFIX}#{jti}"
    end

    def user_revoke_key(user_id)
      "#{BLACKLIST_PREFIX}user:#{user_id}"
    end

    def redis
      @redis ||= if Rails.cache.respond_to?(:redis)
                    Rails.cache.redis
                  elsif defined?(Redis) && ENV['REDIS_URL']
                    Redis.new(url: ENV['REDIS_URL'])
                  else
                    # Fallback to Rails.cache for environments without Redis
                    RedisFallbackCache.new
                  end
    end
  end

  # Minimal fallback that uses Rails.cache when Redis is not directly available
  class RedisFallbackCache
    def setex(key, ttl, value)
      Rails.cache.write(key, value, expires_in: ttl.seconds)
    end

    def get(key)
      Rails.cache.read(key)
    end

    def exists?(key)
      Rails.cache.exist?(key)
    end
  end
end
