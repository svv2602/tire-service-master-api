class CarModel < ApplicationRecord
  # Связи
  belongs_to :brand, class_name: 'CarBrand', foreign_key: 'brand_id'
  has_many :client_cars, foreign_key: 'model_id', dependent: :restrict_with_error
  
  # Валидации
  validates :name, presence: true
  validates :name, uniqueness: { scope: :brand_id }
  
  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :for_brand, ->(brand_id) { where(brand_id: brand_id) }
  scope :alphabetical, -> { order(:name) }
  
  # Методы
  def full_name
    "#{brand.name} #{name}"
  end
end
