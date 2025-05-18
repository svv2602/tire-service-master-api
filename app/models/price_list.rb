class PriceList < ApplicationRecord
  # Связи
  belongs_to :partner
  belongs_to :service_point, optional: true
  has_many :price_list_items, dependent: :destroy
  
  # Валидации
  validates :name, presence: true
  validate :end_date_after_start_date, if: -> { start_date.present? && end_date.present? }
  
  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :current, -> { 
    where('(start_date <= ? OR start_date IS NULL) AND (end_date >= ? OR end_date IS NULL)', Date.current, Date.current)
  }
  scope :by_partner, ->(partner_id) { where(partner_id: partner_id) }
  scope :by_service_point, ->(service_point_id) { where(service_point_id: service_point_id) }
  scope :global_for_partner, ->(partner_id) { where(partner_id: partner_id, service_point_id: nil) }
  
  # Сезонные прайс-листы
  scope :winter, -> { where(season: 'winter') }
  scope :summer, -> { where(season: 'summer') }
  
  # Методы
  def global?
    service_point_id.nil?
  end
  
  private
  
  def end_date_after_start_date
    if end_date <= start_date
      errors.add(:end_date, "must be after start date")
    end
  end
end
