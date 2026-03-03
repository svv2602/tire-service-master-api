# frozen_string_literal: true

class RefundRequest < ApplicationRecord
  # Associations
  belongs_to :payment
  belongs_to :user

  # Validations
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :reason, presence: true
  validates :reason_category, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending approved rejected completed] }

  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :recent, -> { order(created_at: :desc) }

  # Validate refund amount does not exceed payment amount
  validate :amount_does_not_exceed_payment

  private

  def amount_does_not_exceed_payment
    return unless payment && amount

    if amount > payment.amount
      errors.add(:amount, 'cannot exceed payment amount')
    end
  end
end
