class TireType < ApplicationRecord
  # Связи
  has_many :client_cars, dependent: :nullify
  
  # Валидации
  validates :name, presence: true
  
  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :alphabetical, -> { order(:name) }
end
