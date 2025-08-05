class Supplier < ApplicationRecord
  # Связи
  has_many :supplier_tire_products, dependent: :destroy
  has_many :supplier_price_versions, dependent: :destroy
  has_many :tire_orders, dependent: :destroy
  
  # Валидации
  validates :firm_id, presence: true, uniqueness: true, length: { maximum: 50 }
  validates :name, presence: true, length: { maximum: 255 }
  validates :api_key, presence: true, uniqueness: true, length: { maximum: 255 }
  validates :priority, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :by_priority, -> { order(:priority, :name) }
  scope :search, ->(query) do
    return all if query.blank?
    
    query_downcase = query.downcase
    where("LOWER(name) LIKE ? OR LOWER(firm_id) LIKE ?", 
          "%#{query_downcase}%", "%#{query_downcase}%")
  end
  
  # Колбэки
  before_validation :generate_api_key, on: :create, if: -> { api_key.blank? }
  before_validation :normalize_firm_id
  
  # Методы
  def active?
    is_active
  end
  
  def products_count
    supplier_tire_products.count
  end
  
  def in_stock_products_count
    supplier_tire_products.where(in_stock: true).count
  end
  
  def last_version
    supplier_price_versions.order(:uploaded_at).last
  end
  
  def sync_status
    return 'never' unless last_sync_at
    
    time_diff = Time.current - last_sync_at
    case time_diff
    when 0..1.hour
      'recent'
    when 1.hour..1.day
      'today'
    when 1.day..7.days
      'week'
    else
      'old'
    end
  end
  
  def regenerate_api_key!
    generate_api_key
    save!
  end
  
  private
  
  def generate_api_key
    self.api_key = SecureRandom.hex(32)
  end
  
  def normalize_firm_id
    self.firm_id = firm_id&.strip&.upcase
  end
end
