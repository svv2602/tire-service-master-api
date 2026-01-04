# frozen_string_literal: true

class ReviewRequestToken < ApplicationRecord
  belongs_to :booking

  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active, -> { where('expires_at > ?', Time.current).where(used_at: nil) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }
  scope :used, -> { where.not(used_at: nil) }

  def expired?
    expires_at <= Time.current
  end

  def used?
    used_at.present?
  end

  def valid_for_review?
    !expired? && !used?
  end

  def mark_as_used!(ip_address: nil, user_agent: nil)
    update!(
      used_at: Time.current,
      ip_address: ip_address,
      user_agent: user_agent
    )
  end

  # Class methods

  def self.find_valid_token(token)
    active.find_by(token: token)
  end

  def self.cleanup_expired
    expired.delete_all
  end
end
