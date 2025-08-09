# Модель начисленных вознаграждений партнерам
class PartnerReward < ApplicationRecord
  # Связи
  belongs_to :partner
  belongs_to :supplier
  belongs_to :reward_rule
  belongs_to :tire_order, optional: true
  belongs_to :order, optional: true
  
  # Делегирование
  delegate :rule_type, :rule_type_display, to: :reward_rule
  delegate :company_name, to: :partner, prefix: true
  delegate :name, to: :supplier, prefix: true
  
  # Константы статусов
  PAYMENT_STATUSES = {
    'pending' => 'На согласовании',
    'paid' => 'Выплачено',
    'cancelled' => 'Отменено'
  }.freeze
  
  # Валидации
  validates :calculated_amount, presence: true, numericality: { greater_than: 0 }
  validates :payment_status, presence: true, inclusion: { in: PAYMENT_STATUSES.keys }
  validates :calculated_at, presence: true
  validate :must_have_order_reference
  validate :paid_at_presence_for_paid_status
  
  # Скоупы
  scope :pending, -> { where(payment_status: 'pending') }
  scope :paid, -> { where(payment_status: 'paid') }
  scope :cancelled, -> { where(payment_status: 'cancelled') }
  scope :by_partner, ->(partner_id) { where(partner_id: partner_id) }
  scope :by_supplier, ->(supplier_id) { where(supplier_id: supplier_id) }
  scope :by_status, ->(status) { where(payment_status: status) }
  scope :recent, -> { order(calculated_at: :desc) }
  scope :in_period, ->(from, to) { where(calculated_at: from..to) }
  scope :with_associations, -> { includes(:partner, :supplier, :reward_rule, :tire_order, :order) }
  
  # Методы экземпляра
  def payment_status_display
    PAYMENT_STATUSES[payment_status] || payment_status
  end
  
  def pending?
    payment_status == 'pending'
  end
  
  def paid?
    payment_status == 'paid'
  end
  
  def cancelled?
    payment_status == 'cancelled'
  end
  
  def can_be_marked_as_paid?
    pending?
  end
  
  def can_be_cancelled?
    pending?
  end
  
  def mark_as_paid!(notes = nil)
    return false unless can_be_marked_as_paid?
    
    update!(
      payment_status: 'paid',
      paid_at: Time.current,
      notes: [self.notes, notes].compact.join('; ')
    )
  end
  
  def cancel!(reason = nil)
    return false unless can_be_cancelled?
    
    update!(
      payment_status: 'cancelled',
      notes: [self.notes, "Отменено: #{reason}"].compact.join('; ')
    )
  end
  
  def order_reference
    tire_order || order
  end
  
  def order_type
    return 'Корзина' if tire_order.present?
    return 'Интернет-магазин' if order.present?
    'Неизвестно'
  end
  
  def order_number
    if tire_order.present?
      "TireOrder ##{tire_order.id}"
    elsif order.present?
      "Order ##{order.ttn}"
    else
      'N/A'
    end
  end
  
  def order_amount
    if tire_order.present?
      tire_order.total_amount
    elsif order.present?
      order.total_amount
    else
      0
    end
  end
  
  def order_date
    if tire_order.present?
      tire_order.updated_at
    elsif order.present?
      order.order_date
    else
      calculated_at
    end
  end
  
  def formatted_amount
    "#{calculated_amount.to_f} грн"
  end
  
  def formatted_calculated_at
    calculated_at.strftime('%d.%m.%Y %H:%M')
  end
  
  def formatted_paid_at
    paid_at&.strftime('%d.%m.%Y %H:%M') || '-'
  end
  
  # Методы класса
  def self.total_amount_for_partner(partner_id, status = nil)
    scope = by_partner(partner_id)
    scope = scope.by_status(status) if status.present?
    scope.sum(:calculated_amount)
  end
  
  def self.total_amount_for_supplier(supplier_id, status = nil)
    scope = by_supplier(supplier_id)
    scope = scope.by_status(status) if status.present?
    scope.sum(:calculated_amount)
  end
  
  def self.statistics_for_partner(partner_id, period_from = nil, period_to = nil)
    scope = by_partner(partner_id)
    scope = scope.in_period(period_from, period_to) if period_from && period_to
    
    {
      total_pending: scope.pending.sum(:calculated_amount),
      total_paid: scope.paid.sum(:calculated_amount),
      total_cancelled: scope.cancelled.sum(:calculated_amount),
      count_pending: scope.pending.count,
      count_paid: scope.paid.count,
      count_cancelled: scope.cancelled.count
    }
  end
  
  private
  
  def must_have_order_reference
    if tire_order.blank? && order.blank?
      errors.add(:base, 'должен быть связан с заказом (TireOrder или Order)')
    end
    
    if tire_order.present? && order.present?
      errors.add(:base, 'не может быть связан одновременно с TireOrder и Order')
    end
  end
  
  def paid_at_presence_for_paid_status
    if paid? && paid_at.blank?
      errors.add(:paid_at, 'должна быть указана для статуса "Выплачено"')
    end
    
    if !paid? && paid_at.present?
      errors.add(:paid_at, 'должна быть пустой для статуса отличного от "Выплачено"')
    end
  end
end