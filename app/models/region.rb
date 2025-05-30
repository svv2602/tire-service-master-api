class Region < ApplicationRecord
  # Связи
  has_many :cities, dependent: :destroy
  
  # Валидации
  validates :name, presence: true, uniqueness: true
  validates :code, uniqueness: true, allow_nil: true
  
  # Скоупы
  scope :active, -> { where(is_active: true) }
  
  # Методы
  def cities_count
    cities.count
  end
  
  def as_json(options = {})
    super(options).merge(
      'cities_count' => cities_count
    )
  end
end
