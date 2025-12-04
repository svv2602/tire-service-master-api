# frozen_string_literal: true

# ContentSanitizable concern
# Provides HTML content sanitization for models that store user-generated HTML content.
# Uses Rails::Html::SafeListSanitizer with configurable allowed tags and attributes.
#
# Usage:
#   class Article < ApplicationRecord
#     include ContentSanitizable
#     sanitize_fields :content, :content_html
#   end
#
module ContentSanitizable
  extend ActiveSupport::Concern

  # Allowed HTML tags for content sanitization
  ALLOWED_TAGS = %w[
    p br div span
    strong b em i u s strike
    h1 h2 h3 h4 h5 h6
    ul ol li
    a
    img
    table thead tbody tfoot tr th td
    blockquote pre code
    hr
    sub sup
  ].freeze

  # Allowed HTML attributes for content sanitization
  ALLOWED_ATTRIBUTES = %w[
    href target rel
    src alt title width height
    class id style
    colspan rowspan
    data-*
  ].freeze

  # URL schemes allowed in href and src attributes
  ALLOWED_URL_SCHEMES = %w[http https mailto tel].freeze

  included do
    class_attribute :sanitizable_fields, default: []

    before_save :sanitize_content_fields
  end

  class_methods do
    # Define which fields should be sanitized
    # @param fields [Array<Symbol>] field names to sanitize
    def sanitize_fields(*fields)
      self.sanitizable_fields = fields.map(&:to_sym)
    end
  end

  private

  # Sanitizes all configured content fields before save
  def sanitize_content_fields
    return if sanitizable_fields.blank?

    sanitizable_fields.each do |field|
      next unless respond_to?(field) && respond_to?("#{field}=")

      value = send(field)
      next if value.blank?

      sanitized_value = sanitize_html(value)
      send("#{field}=", sanitized_value)
    end
  end

  # Sanitizes HTML content using Rails::Html::SafeListSanitizer
  # @param content [String] the HTML content to sanitize
  # @return [String] sanitized HTML content
  def sanitize_html(content)
    return content if content.blank?

    sanitizer = Rails::Html::SafeListSanitizer.new

    # First pass: sanitize HTML tags and attributes
    sanitized = sanitizer.sanitize(
      content,
      tags: ALLOWED_TAGS,
      attributes: allowed_attributes_list
    )

    # Second pass: remove dangerous URL schemes
    sanitized = remove_dangerous_urls(sanitized)

    # Third pass: remove event handlers (onclick, onerror, etc.)
    sanitized = remove_event_handlers(sanitized)

    sanitized
  end

  # Returns list of allowed attributes including data-* pattern expansion
  def allowed_attributes_list
    # Start with base allowed attributes (excluding data-* pattern)
    attrs = ALLOWED_ATTRIBUTES.reject { |a| a == 'data-*' }

    # Add common data attributes explicitly
    attrs += %w[data-id data-type data-value data-toggle data-target data-dismiss]

    attrs
  end

  # Removes dangerous URL schemes from href and src attributes
  # @param content [String] HTML content
  # @return [String] content with dangerous URLs removed
  def remove_dangerous_urls(content)
    return content if content.blank?

    # Remove javascript: and data: URLs from href attributes
    content = content.gsub(/href\s*=\s*["']?\s*javascript:[^"'>]*/i, 'href="#removed"')
    content = content.gsub(/href\s*=\s*["']?\s*data:[^"'>]*/i, 'href="#removed"')
    content = content.gsub(/href\s*=\s*["']?\s*vbscript:[^"'>]*/i, 'href="#removed"')

    # Remove javascript: and data: URLs from src attributes
    content = content.gsub(/src\s*=\s*["']?\s*javascript:[^"'>]*/i, 'src=""')
    content = content.gsub(/src\s*=\s*["']?\s*data:[^"'>]*/i, 'src=""')

    content
  end

  # Removes all event handler attributes (onclick, onerror, onload, etc.)
  # @param content [String] HTML content
  # @return [String] content with event handlers removed
  def remove_event_handlers(content)
    return content if content.blank?

    # Remove all on* event handler attributes
    content.gsub(/\s+on\w+\s*=\s*["'][^"']*["']/i, '')
           .gsub(/\s+on\w+\s*=\s*[^\s>]+/i, '')
  end
end
