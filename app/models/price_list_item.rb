class PriceListItem < ApplicationRecord
  # Связи
  belongs_to :price_list
  belongs_to :service
  
  # Валидации
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :discount_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :service_id, uniqueness: { scope: :price_list_id }
  validate :discount_price_less_than_price
  
  # Делегирование
  delegate :name, to: :service, prefix: true
  
  private
  
  def discount_price_less_than_price
    return if discount_price.blank? || price.blank?
    
    if discount_price >= price
      errors.add(:discount_price, "must be less than the regular price")
    end
  end
end
