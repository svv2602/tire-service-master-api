class City < ApplicationRecord
  # Связи
  belongs_to :region
  has_many :service_points, dependent: :restrict_with_error
  
  # Валидации
  validates :name, presence: true
  validates :name, uniqueness: { scope: :region_id }
  
  # Скоупы
  scope :active, -> { where(is_active: true) }
  
  # Методы
  def full_name
    "#{name}, #{region.name}"
  end
end
