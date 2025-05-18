class ClientFavoritePoint < ApplicationRecord
  # Связи
  belongs_to :client
  belongs_to :service_point
  
  # Валидации
  validates :client_id, uniqueness: { scope: :service_point_id }
end
