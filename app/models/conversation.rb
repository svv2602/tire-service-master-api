# frozen_string_literal: true

# Model for storing tire chat conversations
class Conversation < ApplicationRecord
  # Associations
  belongs_to :user, optional: true
  has_many :messages, class_name: 'ConversationMessage', dependent: :destroy

  # Validations
  validates :session_id, presence: true
  validates :status, presence: true, inclusion: { in: %w[active closed archived] }

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :recent, -> { order(updated_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
  scope :for_session, ->(session_id) { where(session_id: session_id) }

  # Class methods
  class << self
    # Find or create conversation for session/user
    def find_or_create_for(session_id:, user: nil)
      # If user is provided, try to find by user first
      if user
        existing = active.for_user(user).order(updated_at: :desc).first
        return existing if existing && existing.updated_at > 1.hour.ago
      end

      # Otherwise find by session_id
      existing = active.for_session(session_id).order(updated_at: :desc).first
      return existing if existing

      # Create new conversation
      create!(
        session_id: session_id,
        user: user,
        status: 'active'
      )
    end
  end

  # Get context for AI (last N messages formatted for OpenAI)
  def context_for_ai(limit: 20)
    messages.order(created_at: :asc).last(limit).map do |msg|
      {
        role: msg.role,
        content: msg.content
      }
    end
  end

  # Add a user message
  def add_user_message(content)
    message = messages.create!(
      role: 'user',
      content: content
    )
    touch # Update conversation timestamp
    message
  end

  # Add an assistant message with optional metadata
  def add_assistant_message(content, metadata: {})
    message = messages.create!(
      role: 'assistant',
      content: content,
      metadata: metadata
    )
    touch
    message
  end

  # Add a system message
  def add_system_message(content)
    messages.create!(
      role: 'system',
      content: content
    )
  end

  # Close conversation
  def close!
    update!(status: 'closed')
  end

  # Archive conversation
  def archive!
    update!(status: 'archived')
  end

  # Get last N messages
  def recent_messages(limit: 10)
    messages.order(created_at: :desc).limit(limit).reverse
  end

  # Check if conversation is active
  def active?
    status == 'active'
  end

  # Get total message count
  def message_count
    messages.count
  end

  # Get user message count
  def user_message_count
    messages.where(role: 'user').count
  end
end
