# frozen_string_literal: true

# Model for storing individual messages in a conversation
class ConversationMessage < ApplicationRecord
  # Associations
  belongs_to :conversation, touch: true

  # Validations
  validates :role, presence: true, inclusion: { in: %w[user assistant system] }
  validates :content, presence: true

  # Scopes
  scope :by_role, ->(role) { where(role: role) }
  scope :user_messages, -> { where(role: 'user') }
  scope :assistant_messages, -> { where(role: 'assistant') }
  scope :system_messages, -> { where(role: 'system') }
  scope :chronological, -> { order(created_at: :asc) }
  scope :recent_first, -> { order(created_at: :desc) }

  # Check message type
  def user?
    role == 'user'
  end

  def assistant?
    role == 'assistant'
  end

  def system?
    role == 'system'
  end

  # Get products from metadata (if any)
  def products
    metadata['products'] || []
  end

  # Get search params from metadata (if any)
  def search_params
    metadata['search_params'] || {}
  end

  # Check if message has products
  def has_products?
    products.any?
  end

  # Format for API response
  def as_api_json
    {
      id: id,
      role: role,
      content: content,
      products: products,
      search_params: search_params,
      created_at: created_at.iso8601
    }
  end
end
