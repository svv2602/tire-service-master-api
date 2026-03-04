# Model for storing partner webhook endpoint configurations.
# Each endpoint can subscribe to specific events and receives
# JSON payloads signed with HMAC-SHA256.
class WebhookEndpoint < ApplicationRecord
  # Associations
  belongs_to :partner
  has_many :webhook_deliveries, dependent: :destroy

  # Supported webhook events
  SUPPORTED_EVENTS = %w[
    booking.created
    booking.confirmed
    booking.completed
    order.status_changed
    review.created
  ].freeze

  # Validations
  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: 'must be a valid HTTP(S) URL' }
  validates :secret, presence: true
  validates :events, presence: true
  validate :events_must_be_supported

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :for_event, ->(event) { active.where('? = ANY(events)', event) }

  # Callbacks
  before_validation :generate_secret, on: :create, if: -> { secret.blank? }

  # Generate a new secret token
  def regenerate_secret!
    update!(secret: SecureRandom.hex(32))
  end

  private

  # Validate that all events are from the supported list
  def events_must_be_supported
    return if events.blank?

    invalid_events = events - SUPPORTED_EVENTS
    if invalid_events.any?
      errors.add(:events, "contain unsupported events: #{invalid_events.join(', ')}")
    end
  end

  # Auto-generate secret on creation if not provided
  def generate_secret
    self.secret = SecureRandom.hex(32)
  end
end
