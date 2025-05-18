class Administrator < ApplicationRecord
  # Связи
  belongs_to :user
  
  # Валидации
  validates :user_id, presence: true, uniqueness: true
  validates :access_level, numericality: { only_integer: true, greater_than: 0 }
end
