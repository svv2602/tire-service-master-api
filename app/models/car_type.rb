class CarType < ApplicationRecord
  # Связи
  has_many :bookings, dependent: :restrict_with_error
  has_many :client_cars, dependent: :nullify
  
  # Валидации
  validates :name, presence: true, uniqueness: true
  
  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :alphabetical, -> { order(:name) }
end
