# Service for managing loyalty program operations.
# Handles point accrual for bookings, reviews, referrals, and tire orders.
class LoyaltyService < ApplicationService
  # Award points for a completed booking
  def self.award_booking_completed(booking)
    return unless booking.client&.user

    account = find_or_create_account(booking.client.user)
    points = LoyaltyTransaction::POINTS_MAP['booking_completed']

    account.credit_points!(
      points,
      reason: 'booking_completed',
      description: "Points for completed booking ##{booking.id}",
      booking: booking
    )

    log_award(account, points, 'booking_completed')
  end

  # Award points for submitting a review
  def self.award_review_submitted(review)
    return unless review.client&.user

    account = find_or_create_account(review.client.user)
    points = LoyaltyTransaction::POINTS_MAP['review_submitted']

    account.credit_points!(
      points,
      reason: 'review_submitted',
      description: "Points for review ##{review.id}",
      review: review
    )

    log_award(account, points, 'review_submitted')
  end

  # Award points for a referral
  def self.award_referral(user, referred_user)
    return unless user

    account = find_or_create_account(user)
    points = LoyaltyTransaction::POINTS_MAP['referral']

    account.credit_points!(
      points,
      reason: 'referral',
      description: "Referral bonus for inviting user ##{referred_user.id}",
      referral_user: referred_user
    )

    log_award(account, points, 'referral')
  end

  # Award points for a tire order (1 point per 100 UAH)
  def self.award_tire_order(tire_order)
    return unless tire_order.user

    account = find_or_create_account(tire_order.user)
    points = LoyaltyTransaction.points_for_tire_order(tire_order.total_amount)
    return if points <= 0

    account.credit_points!(
      points,
      reason: 'tire_order',
      description: "Points for tire order ##{tire_order.id} (#{tire_order.total_amount} UAH)",
      tire_order: tire_order
    )

    log_award(account, points, 'tire_order')
  end

  # Find or create a loyalty account for a user
  def self.find_or_create_account(user)
    LoyaltyAccount.find_or_create_by!(user: user) do |account|
      account.points = 0
      account.level = 'bronze'
    end
  end

  # Get loyalty balance info for a user
  def self.balance(user)
    account = find_or_create_account(user)
    {
      points: account.points,
      level: account.level,
      level_progress: account.level_progress,
      points_to_next_level: account.points_to_next_level,
      next_level: account.next_level
    }
  end

  # Get paginated transaction history for a user
  def self.transactions(user, page: 1, per_page: 20)
    account = find_or_create_account(user)
    account.loyalty_transactions
           .recent
           .page(page)
           .per(per_page)
  end

  private

  def self.log_award(account, points, reason)
    Rails.logger.info(
      "[LoyaltyService] Awarded #{points} points to user ##{account.user_id} " \
      "for #{reason}. Total: #{account.points}, Level: #{account.level}"
    )
  end
end
