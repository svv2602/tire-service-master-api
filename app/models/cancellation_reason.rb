class CancellationReason < ApplicationRecord
  # Связи
  has_many :bookings, foreign_key: 'cancellation_reason_id', dependent: :nullify
  
  # Валидации
  validates :name, presence: true
  
  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :for_clients, -> { where(is_for_client: true) }
  scope :for_partners, -> { where(is_for_partner: true) }
  scope :sorted, -> { order(sort_order: :asc) }
end
