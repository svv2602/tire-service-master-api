module TireOrderStatuses
  extend ActiveSupport::Concern

  included do
    include AASM

    # Status definitions with metadata
    STATUSES = {
      'draft' => { display_name: 'Корзина', color: '#9E9E9E', sort_order: 0 },
      'submitted' => { display_name: 'Отправлен', color: '#FFC107', sort_order: 1 },
      'confirmed' => { display_name: 'Подтверждён', color: '#4CAF50', sort_order: 2 },
      'processing' => { display_name: 'В обработке', color: '#2196F3', sort_order: 3 },
      'shipped' => { display_name: 'Отправлен', color: '#03A9F4', sort_order: 4 },
      'delivered' => { display_name: 'Доставлен', color: '#8BC34A', sort_order: 5 },
      'completed' => { display_name: 'Завершён', color: '#4CAF50', sort_order: 6 },
      'cancelled' => { display_name: 'Отменён', color: '#F44336', sort_order: 7 },
      'archived' => { display_name: 'Архивирован', color: '#757575', sort_order: 8 }
    }.freeze

    # Status groups
    ACTIVE_STATUSES = %w[submitted confirmed processing shipped].freeze
    DELIVERY_STATUSES = %w[shipped delivered].freeze
    FINAL_STATUSES = %w[completed cancelled archived].freeze
    CANCELLABLE_BY_USER = %w[draft submitted confirmed processing].freeze
    CANCELLABLE_BY_ADMIN = %w[draft submitted confirmed processing shipped].freeze

    # AASM state machine
    aasm column: :status, whiny_transitions: false do
      state :draft, initial: true
      state :submitted
      state :confirmed
      state :processing
      state :shipped
      state :delivered
      state :completed
      state :cancelled
      state :archived

      # Submit order from cart
      event :submit do
        transitions from: :draft, to: :submitted, guard: :has_items?
        after do
          calculate_partner_reward if should_calculate_reward?
        end
      end

      # Supplier confirms the order
      event :confirm do
        transitions from: :submitted, to: :confirmed
        after do
          calculate_partner_reward if should_calculate_reward?
        end
      end

      # Order is being processed/prepared
      event :start_processing do
        transitions from: :confirmed, to: :processing
      end

      # Order shipped
      event :ship do
        transitions from: :processing, to: :shipped
        before do
          self.shipped_at = Time.current unless shipped_at
        end
      end

      # Order delivered
      event :deliver do
        transitions from: :shipped, to: :delivered
        before do
          self.delivered_at = Time.current unless delivered_at
        end
      end

      # Complete the order
      event :complete do
        transitions from: [:processing, :delivered], to: :completed
        after do
          calculate_partner_reward if should_calculate_reward?
        end
      end

      # Cancel the order
      event :cancel do
        transitions from: CANCELLABLE_BY_ADMIN, to: :cancelled
      end

      # Archive the order
      event :archive do
        transitions from: [:completed, :cancelled], to: :archived
      end
    end

    # Scopes
    scope :pending, -> { where(status: 'submitted') }
    scope :confirmed, -> { where(status: 'confirmed') }
    scope :processing, -> { where(status: 'processing') }
    scope :shipped, -> { where(status: 'shipped') }
    scope :delivered, -> { where(status: 'delivered') }
    scope :completed, -> { where(status: 'completed') }
    scope :cancelled, -> { where(status: 'cancelled') }
    scope :archived, -> { where(status: 'archived') }
    scope :active, -> { where(status: ACTIVE_STATUSES) }
    scope :final, -> { where(status: FINAL_STATUSES) }
    scope :in_delivery, -> { where(status: DELIVERY_STATUSES) }
  end

  # Instance methods
  def status_display
    STATUSES.dig(status, :display_name) || status&.humanize
  end

  def status_color
    STATUSES.dig(status, :color) || '#9E9E9E'
  end

  def active_status?
    ACTIVE_STATUSES.include?(status)
  end

  def final_status?
    FINAL_STATUSES.include?(status)
  end

  def can_be_cancelled_by_user?
    CANCELLABLE_BY_USER.include?(status)
  end

  def can_be_cancelled_by_admin?
    CANCELLABLE_BY_ADMIN.include?(status)
  end

  def can_be_archived?
    %w[completed cancelled].include?(status)
  end

  # Available transitions for current state
  def available_events
    aasm.events(permitted: true).map(&:name)
  end

  private

  def has_items?
    tire_order_items.any?
  end

  def should_calculate_reward?
    %w[submitted confirmed completed].include?(status)
  end
end
