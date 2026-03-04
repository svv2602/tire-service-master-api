class Amenity < ApplicationRecord
  include CacheVersioning

  # Связи
  has_many :service_point_amenities, dependent: :destroy
  has_many :service_points, through: :service_point_amenities

  # Валидации
  validates :name, presence: true

  # Cache invalidation on data changes
  after_commit :increment_cache_version
end
