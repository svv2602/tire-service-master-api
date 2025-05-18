class ServiceCategory < ApplicationRecord
  # Связи
  has_many :services, foreign_key: 'category_id', dependent: :restrict_with_error
  
  # Валидации
  validates :name, presence: true, uniqueness: true
  
  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :sorted, -> { order(sort_order: :asc) }
end
