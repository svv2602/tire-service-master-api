# frozen_string_literal: true

# Concern for HTTP caching headers (ETag, Cache-Control)
# Use for read-only endpoints to improve client-side caching
module HttpCacheable
  extend ActiveSupport::Concern

  included do
    before_action :set_cache_headers, only: [:index, :show]
  end

  private

  # Sets Cache-Control headers for public, cacheable responses
  # @param max_age [Integer] Max age in seconds (default: 60)
  # @param public_cache [Boolean] Whether response can be cached by CDNs (default: false)
  def set_cache_control(max_age: 60, public_cache: false)
    if public_cache
      response.headers['Cache-Control'] = "public, max-age=#{max_age}"
    else
      response.headers['Cache-Control'] = "private, max-age=#{max_age}"
    end
  end

  # Sets ETag for conditional GET requests
  # Returns 304 Not Modified if content hasn't changed
  # @param records [ActiveRecord::Relation, Array] Records to generate ETag from
  # @param extra_data [Array] Additional data to include in ETag
  def set_etag_for(records, *extra_data)
    etag_data = [
      records.respond_to?(:maximum) ? records.maximum(:updated_at) : records.map(&:updated_at).max,
      records.respond_to?(:count) ? records.count : records.size,
      *extra_data
    ]

    fresh_when(etag: etag_data, last_modified: etag_data.first)
  end

  # Sets ETag for single record
  # @param record [ActiveRecord::Base] Record to generate ETag from
  def set_etag_for_record(record)
    return unless record.present?

    fresh_when(record)
  end

  # Default cache headers for API responses (no caching)
  def set_cache_headers
    response.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate'
    response.headers['Pragma'] = 'no-cache'
    response.headers['Expires'] = '0'
  end

  # Enable caching for list endpoints
  # @param max_age [Integer] Max age in seconds
  def cache_for(max_age)
    response.headers['Cache-Control'] = "private, max-age=#{max_age}"
    response.headers.delete('Pragma')
    response.headers.delete('Expires')
  end

  # Enable public caching (for CDN)
  # @param max_age [Integer] Max age in seconds
  def public_cache_for(max_age)
    response.headers['Cache-Control'] = "public, max-age=#{max_age}, s-maxage=#{max_age * 2}"
    response.headers.delete('Pragma')
    response.headers.delete('Expires')
  end

  # Set Vary header for cache key differentiation
  # @param headers [Array<String>] Headers to vary on
  def vary_on(*headers)
    response.headers['Vary'] = headers.join(', ')
  end
end
