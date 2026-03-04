# Loyalty account for tracking client loyalty points and level
class LoyaltyAccount < ApplicationRecord
  # Loyalty level thresholds
  LEVELS = {
    'bronze' => 0..99,
    'silver' => 100..499,
    'gold' => 500..Float::INFINITY
  }.freeze

  LEVEL_NAMES = LEVELS.keys.freeze

  # Associations
  belongs_to :user
  has_many :loyalty_transactions, dependent: :destroy

  # Validations
  validates :points, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :level, presence: true, inclusion: { in: LEVEL_NAMES }
  validates :user_id, uniqueness: true

  # Callbacks
  before_save :recalculate_level, if: :points_changed?

  # Scopes
  scope :by_level, ->(level) { where(level: level) }
  scope :with_user, -> { includes(:user) }

  # Determine correct level based on current points
  def calculated_level
    LEVELS.each do |level_name, range|
      return level_name if range.include?(points)
    end
    'bronze'
  end

  # Add points and create a transaction record
  def credit_points!(amount, reason:, description: nil, booking: nil, tire_order: nil, review: nil, referral_user: nil)
    return if amount <= 0

    transaction do
      self.points += amount
      save!

      loyalty_transactions.create!(
        points: amount,
        reason: reason,
        description: description,
        booking: booking,
        tire_order: tire_order,
        review: review,
        referral_user: referral_user
      )
    end
  end

  # Deduct points (for future redemption feature)
  def debit_points!(amount, reason:, description: nil)
    return if amount <= 0
    raise InsufficientPointsError, "Not enough points: #{points} < #{amount}" if points < amount

    transaction do
      self.points -= amount
      save!

      loyalty_transactions.create!(
        points: -amount,
        reason: reason,
        description: description
      )
    end
  end

  # Level progress percentage toward next level
  def level_progress
    case level
    when 'bronze'
      [(points.to_f / 100 * 100).round, 100].min
    when 'silver'
      [((points - 100).to_f / 400 * 100).round, 100].min
    when 'gold'
      100
    else
      0
    end
  end

  # Points needed to reach the next level
  def points_to_next_level
    case level
    when 'bronze'
      [100 - points, 0].max
    when 'silver'
      [500 - points, 0].max
    when 'gold'
      0
    else
      0
    end
  end

  # Next level name
  def next_level
    case level
    when 'bronze' then 'silver'
    when 'silver' then 'gold'
    when 'gold' then nil
    end
  end

  # Custom error for insufficient points
  class InsufficientPointsError < StandardError; end

  private

  def recalculate_level
    self.level = calculated_level
  end
end
