# frozen_string_literal: true

# Model for storing Google Calendar OAuth tokens and settings
# Each partner or service point can have one Google Calendar connection
class GoogleCalendarSetting < ApplicationRecord
  belongs_to :partner, optional: true
  belongs_to :service_point, optional: true

  encrypts :access_token, :refresh_token

  validates :partner_id, uniqueness: true, allow_nil: true
  validates :service_point_id, uniqueness: true, allow_nil: true
  validate :must_have_owner

  # Scopes
  scope :connected, -> { where.not(refresh_token: nil) }
  scope :expired, -> { where('token_expires_at < ?', Time.current) }

  # Check if token is valid
  def token_valid?
    access_token.present? && token_expires_at && token_expires_at > Time.current
  end

  # Check if connected to Google
  def connected?
    refresh_token.present?
  end

  private

  def must_have_owner
    return if partner_id.present? || service_point_id.present?

    errors.add(:base, 'Must belong to either partner or service point')
  end
end
