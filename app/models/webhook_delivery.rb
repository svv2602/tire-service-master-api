# Model for tracking individual webhook delivery attempts.
# Records the event, payload, HTTP response, and delivery status.
class WebhookDelivery < ApplicationRecord
  # Associations
  belongs_to :webhook_endpoint

  # Status constants
  STATUSES = %w[pending success failed].freeze

  # Validations
  validates :event, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :successful, -> { where(status: 'success') }
  scope :failed, -> { where(status: 'failed') }
  scope :pending, -> { where(status: 'pending') }

  # Mark delivery as successful
  def mark_success!(response_code:, response_body: nil)
    update!(
      status: 'success',
      response_code: response_code,
      response_body: response_body&.truncate(5000),
      delivered_at: Time.current
    )
  end

  # Mark delivery as failed
  def mark_failed!(response_code: nil, response_body: nil, error_message: nil)
    update!(
      status: 'failed',
      response_code: response_code,
      response_body: response_body&.truncate(5000),
      error_message: error_message&.truncate(2000)
    )
  end
end
