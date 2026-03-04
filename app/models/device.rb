# frozen_string_literal: true

# Device model for mobile push notification token registration.
# Stores APNs (iOS) and FCM (Android) device tokens linked to users.
class Device < ApplicationRecord
  belongs_to :user

  # Validations
  validates :device_token, presence: true, uniqueness: true
  validates :platform, presence: true, inclusion: { in: %w[ios android] }
  validates :app_version, length: { maximum: 20 }, allow_blank: true
  validates :os_version, length: { maximum: 20 }, allow_blank: true
  validates :device_name, length: { maximum: 100 }, allow_blank: true
  validates :device_model, length: { maximum: 100 }, allow_blank: true

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :ios, -> { where(platform: 'ios') }
  scope :android, -> { where(platform: 'android') }
  scope :recent, -> { order(last_used_at: :desc) }

  # Activate the device for receiving push notifications
  def activate!
    update!(is_active: true, last_used_at: Time.current)
  end

  # Deactivate the device (e.g. user logged out)
  def deactivate!
    update!(is_active: false)
  end

  # Mark device as recently used
  def touch_last_used!
    touch(:last_used_at)
  end

  # Check if device token is stale (no activity for 90 days)
  def stale?
    last_used_at.nil? || last_used_at < 90.days.ago
  end

  # Check if device can receive push notifications
  def can_receive_push?
    is_active? && !stale?
  end
end
