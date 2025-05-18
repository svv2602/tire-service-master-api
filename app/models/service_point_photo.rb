class ServicePointPhoto < ApplicationRecord
  # Связи
  belongs_to :service_point
  
  # Валидации
  validates :photo_url, presence: true
  
  # Скоупы
  scope :sorted, -> { order(sort_order: :asc) }
end
