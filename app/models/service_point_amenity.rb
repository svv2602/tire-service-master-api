class ServicePointAmenity < ApplicationRecord
  # Связи
  belongs_to :service_point
  belongs_to :amenity
  
  # Валидации
  validates :service_point_id, uniqueness: { scope: :amenity_id }
end
