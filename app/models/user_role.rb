class UserRole < ApplicationRecord
  # Связи
  has_many :users, foreign_key: 'role_id', dependent: :restrict_with_error
  
  # Валидации
  validates :name, presence: true, uniqueness: true
  
  # Скоупы
  scope :active, -> { where(is_active: true) }
end
