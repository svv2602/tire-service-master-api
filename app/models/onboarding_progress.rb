# frozen_string_literal: true

class OnboardingProgress < ApplicationRecord
  # Associations
  belongs_to :user

  # Validations
  validates :user_id, uniqueness: true

  # Onboarding steps per role
  STEPS_BY_ROLE = {
    'admin' => [
      { key: 'welcome', title: 'Welcome' },
      { key: 'review_dashboard', title: 'Review dashboard' },
      { key: 'manage_users', title: 'Manage users' },
      { key: 'configure_settings', title: 'Configure settings' }
    ],
    'partner' => [
      { key: 'welcome', title: 'Welcome' },
      { key: 'create_service_point', title: 'Create service point' },
      { key: 'setup_schedule', title: 'Setup schedule' },
      { key: 'add_services', title: 'Add services' },
      { key: 'review_orders', title: 'Review orders' }
    ],
    'client' => [
      { key: 'welcome', title: 'Welcome' },
      { key: 'add_car', title: 'Add your car' },
      { key: 'search_service', title: 'Search for service' },
      { key: 'make_booking', title: 'Make a booking' }
    ],
    'supplier' => [
      { key: 'welcome', title: 'Welcome' },
      { key: 'upload_price', title: 'Upload price list' },
      { key: 'review_products', title: 'Review products' },
      { key: 'manage_orders', title: 'Manage orders' }
    ]
  }.freeze

  # Default steps for unknown roles
  DEFAULT_STEPS = [
    { key: 'welcome', title: 'Welcome' }
  ].freeze

  # Instance methods
  def role
    user&.role&.name || 'client'
  end

  def steps_definition
    STEPS_BY_ROLE[role] || DEFAULT_STEPS
  end

  def steps
    steps_definition.map do |step|
      step.merge(completed: completed_steps.include?(step[:key]))
    end
  end

  def current_step
    first_incomplete = steps.find { |s| !s[:completed] }
    first_incomplete ? first_incomplete[:key] : steps.last&.dig(:key)
  end

  def progress_percent
    return 0 if steps_definition.empty?

    completed_count = completed_steps.count { |s| steps_definition.any? { |d| d[:key] == s } }
    ((completed_count.to_f / steps_definition.size) * 100).round
  end

  def mark_step_completed!(step_key)
    return if completed_steps.include?(step_key)

    self.completed_steps = completed_steps + [step_key]
    save!
  end
end
