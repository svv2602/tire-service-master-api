class TireOrder < ApplicationRecord
  # Include AASM state machine for order statuses
  include TireOrderStatuses

  # Associations
  belongs_to :user
  belongs_to :supplier
  belongs_to :partner, optional: true
  has_many :tire_order_items, dependent: :destroy
  has_many :supplier_tire_products, through: :tire_order_items

  # Rewards system
  has_many :partner_rewards, dependent: :destroy

  # Validations
  validates :client_name, presence: true, length: { maximum: 255 }
  validates :client_phone, presence: true,
            format: {
              with: /\A\+?[\d\s\-\(\)]{10,20}\z/,
              message: 'должен быть в правильном формате'
            }
  validates :total_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :tracking_number, length: { maximum: 100 }, allow_blank: true

  # Scopes (additional to those from TireOrderStatuses)
  scope :by_status, ->(status) { where(status: status) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_supplier, ->(supplier_id) { where(supplier_id: supplier_id) }
  scope :by_partner, ->(partner_id) { where(partner_id: partner_id) }
  scope :recent, -> { order(updated_at: :desc) }
  scope :created_between, ->(from, to) { where(created_at: from..to) }

  # Skip broadcasts attribute (for tests)
  attr_accessor :skip_broadcasts

  # Callbacks
  before_save :calculate_total_amount
  after_update :clear_empty_draft_orders

  # ActionCable broadcasts for real-time updates (only for submitted orders, not drafts)
  after_commit :broadcast_new_order, on: :create, if: -> { status != 'draft' && !skip_broadcasts }
  after_commit :broadcast_status_change, on: :update, if: -> { saved_change_to_status? && !skip_broadcasts }
  after_commit :broadcast_order_update, on: :update, if: -> { !saved_change_to_status? && !skip_broadcasts }

  # Instance methods
  def items_count
    tire_order_items.sum(:quantity)
  end

  def formatted_total
    return 'Не указана' unless total_amount
    "#{total_amount.to_f} UAH"
  end

  def can_be_edited?
    draft?
  end

  # Partner determination (for supplier's view of orders)
  def ordering_partner
    return partner if partner.present?

    # Try to determine partner from user
    if user&.partner?
      user.partner
    elsif user&.operator?
      user.operator&.partner
    elsif user&.manager?
      user.manager&.partner
    end
  end

  # Shipping helpers
  def mark_as_shipped!(tracking_number_value = nil)
    self.tracking_number = tracking_number_value if tracking_number_value.present?
    ship!
  end

  def delivery_days
    return nil unless shipped_at && delivered_at
    ((delivered_at - shipped_at) / 1.day).round
  end

  private

  def calculate_total_amount
    tire_order_items.reload if tire_order_items.loaded?
    self.total_amount = tire_order_items.sum { |item| item.quantity * item.price_at_order }
  end

  def clear_empty_draft_orders
    if draft? && tire_order_items.empty? && updated_at < 30.days.ago
      destroy
    end
  end

  # Calculate partner reward (called by AASM callbacks)
  def calculate_partner_reward
    return unless user&.partner? || user&.operator?

    service = RewardCalculationService.new(self)

    if service.reward_exists?
      service.recalculate_existing_reward
    else
      service.calculate_and_create_reward
    end
  rescue StandardError => e
    Rails.logger.error "Ошибка расчета вознаграждения для TireOrder ##{id}: #{e.message}"
  end

  # === ACTIONCABLE BROADCASTS ===

  # Broadcast new order to supplier via WebSocket
  def broadcast_new_order
    SupplierOrdersChannel.broadcast_new_order(self)
  rescue StandardError => e
    Rails.logger.error "[ActionCable] Failed to broadcast new order: #{e.message}"
  end

  # Broadcast status change to supplier via WebSocket
  def broadcast_status_change
    if cancelled?
      SupplierOrdersChannel.broadcast_cancellation(self)
    else
      SupplierOrdersChannel.broadcast_status_change(self)
    end
  rescue StandardError => e
    Rails.logger.error "[ActionCable] Failed to broadcast status change: #{e.message}"
  end

  # Broadcast order update (tracking, notes, etc.) to supplier
  def broadcast_order_update
    SupplierOrdersChannel.broadcast_update(self)
  rescue StandardError => e
    Rails.logger.error "[ActionCable] Failed to broadcast order update: #{e.message}"
  end
end
