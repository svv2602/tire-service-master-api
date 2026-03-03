# frozen_string_literal: true

class Payment < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :refund_requests, dependent: :destroy

  # Validations
  validates :payment_id, presence: true, uniqueness: true
  validates :provider, presence: true
  validates :payment_type, presence: true, inclusion: { in: %w[booking order] }
  validates :entity_id, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending success failed refunded partially_refunded] }

  # Scopes
  scope :by_type, ->(type) { where(payment_type: type) if type.present? }
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :recent, -> { order(created_at: :desc) }

  # Instance methods
  def booking?
    payment_type == 'booking'
  end

  def order?
    payment_type == 'order'
  end

  def related_entity
    if booking?
      Booking.find_by(id: entity_id)
    elsif order?
      TireOrder.find_by(id: entity_id)
    end
  end
end
