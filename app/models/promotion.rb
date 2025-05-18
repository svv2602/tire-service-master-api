class Promotion < ApplicationRecord
  # Связи
  belongs_to :partner
  belongs_to :service_point, optional: true
  
  # Валидации
  validates :title, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :discount_percent, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :discount_amount, numericality: { greater_than: 0 }, allow_nil: true
  validate :end_date_after_start_date
  validate :either_percent_or_amount
  
  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :current, -> { where('start_date <= ? AND end_date >= ?', Date.current, Date.current) }
  scope :upcoming, -> { where('start_date > ?', Date.current) }
  scope :past, -> { where('end_date < ?', Date.current) }
  scope :by_partner, ->(partner_id) { where(partner_id: partner_id) }
  scope :by_service_point, ->(service_point_id) { where(service_point_id: service_point_id) }
  
  # Методы
  def global?
    service_point_id.nil?
  end
  
  def discount_type
    if discount_percent.present?
      :percent
    elsif discount_amount.present?
      :amount
    else
      :none
    end
  end
  
  private
  
  def end_date_after_start_date
    return unless start_date && end_date
    
    if end_date <= start_date
      errors.add(:end_date, "must be after start date")
    end
  end
  
  def either_percent_or_amount
    if discount_percent.present? && discount_amount.present?
      errors.add(:base, "Provide either discount percent or amount, not both")
    elsif discount_percent.blank? && discount_amount.blank?
      errors.add(:base, "Either discount percent or amount must be provided")
    end
  end
end
