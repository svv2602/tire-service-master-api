# Individual loyalty points transaction record
class LoyaltyTransaction < ApplicationRecord
  # Valid reasons for point transactions
  REASONS = %w[
    booking_completed
    review_submitted
    referral
    tire_order
    manual_adjustment
    points_redeemed
  ].freeze

  # Points awarded per reason
  POINTS_MAP = {
    'booking_completed' => 10,
    'review_submitted' => 5,
    'referral' => 50
    # tire_order is dynamic: 1 point per 100 UAH
  }.freeze

  # Associations
  belongs_to :loyalty_account
  belongs_to :booking, optional: true
  belongs_to :tire_order, optional: true
  belongs_to :review, optional: true
  belongs_to :referral_user, class_name: 'User', optional: true

  # Validations
  validates :points, numericality: { only_integer: true, other_than: 0 }
  validates :reason, presence: true, inclusion: { in: REASONS }

  # Scopes
  scope :credits, -> { where('points > 0') }
  scope :debits, -> { where('points < 0') }
  scope :by_reason, ->(reason) { where(reason: reason) }
  scope :recent, -> { order(created_at: :desc) }

  # Calculate points for a tire order based on total amount in UAH
  def self.points_for_tire_order(total_amount_uah)
    (total_amount_uah / 100).to_i
  end
end
