class CarBrand < ApplicationRecord
  # Связи
  has_many :car_models, foreign_key: 'brand_id', dependent: :destroy
  has_many :client_cars, foreign_key: 'brand_id', dependent: :restrict_with_error
  
  # Валидации
  validates :name, presence: true, uniqueness: true
  
  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :alphabetical, -> { order(:name) }
end
