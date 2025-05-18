class Amenity < ApplicationRecord
  # Связи
  has_many :service_point_amenities, dependent: :destroy
  has_many :service_points, through: :service_point_amenities
  
  # Валидации
  validates :name, presence: true
end
