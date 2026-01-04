# frozen_string_literal: true

# Model for storing predefined review reply templates
# Templates can be global (partner_id nil) or partner-specific
class ReviewReplyTemplate < ApplicationRecord
  # Associations
  belongs_to :partner, optional: true

  # Constants for template categories
  CATEGORIES = {
    'general' => 'General',
    'positive' => 'Positive feedback',
    'negative' => 'Negative feedback',
    'neutral' => 'Neutral feedback',
    'thank_you' => 'Thank you message',
    'apology' => 'Apology message',
    'improvement' => 'Improvement promise'
  }.freeze

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :content, presence: true, length: { maximum: 2000 }
  validates :category, presence: true, inclusion: { in: CATEGORIES.keys }
  validates :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :global, -> { where(partner_id: nil) }
  scope :for_partner, ->(partner_id) { where(partner_id: partner_id) }
  scope :by_category, ->(category) { where(category: category) }
  scope :ordered, -> { order(sort_order: :asc, name: :asc) }
  scope :popular, -> { order(usage_count: :desc) }

  # Get templates available for a partner (global + partner-specific)
  scope :available_for_partner, ->(partner_id) {
    where(is_active: true)
      .where('partner_id IS NULL OR partner_id = ?', partner_id)
      .order(partner_id: :desc, sort_order: :asc, name: :asc)
  }

  # Instance methods

  # Check if this is a global template
  def global?
    partner_id.nil?
  end

  # Increment usage counter
  def increment_usage!
    increment!(:usage_count)
  end

  # Apply template variables (for future extension)
  def render_with_variables(variables = {})
    result = content.dup
    variables.each do |key, value|
      result.gsub!("{#{key}}", value.to_s)
    end
    result
  end

  # Category display name
  def category_display_name
    CATEGORIES[category] || category.humanize
  end

  # Class methods

  # Get default templates for seeding
  def self.default_templates
    [
      {
        name: 'Thank you for positive review',
        content: "Thank you for your positive review! We're glad you had a great experience at our service point. We look forward to serving you again!",
        category: 'positive',
        sort_order: 1
      },
      {
        name: 'Thank you for feedback',
        content: "Thank you for taking the time to leave a review. Your feedback helps us improve our services. We hope to see you again soon!",
        category: 'thank_you',
        sort_order: 2
      },
      {
        name: 'Apology for inconvenience',
        content: "We sincerely apologize for any inconvenience you experienced. Your satisfaction is our priority, and we are committed to improving based on your feedback.",
        category: 'apology',
        sort_order: 3
      },
      {
        name: 'We will improve',
        content: "Thank you for sharing your concerns. We take all feedback seriously and are actively working to improve our services. We hope to have the opportunity to serve you better in the future.",
        category: 'improvement',
        sort_order: 4
      },
      {
        name: 'General response',
        content: "Thank you for your review. We appreciate your feedback and are always striving to provide the best service possible.",
        category: 'general',
        sort_order: 5
      }
    ]
  end

  # Seed default templates
  def self.seed_defaults!
    default_templates.each do |attrs|
      find_or_create_by!(name: attrs[:name], partner_id: nil) do |template|
        template.assign_attributes(attrs)
      end
    end
  end
end
