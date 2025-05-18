class ManagerServicePoint < ApplicationRecord
  # Связи
  belongs_to :manager
  belongs_to :service_point
  
  # Валидации
  validates :manager_id, uniqueness: { scope: :service_point_id }
end
