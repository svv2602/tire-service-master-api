class BookingService < ApplicationRecord
  # Связи
  belongs_to :booking
  belongs_to :service
  
  # Валидации
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  
  # Делегирование
  delegate :name, to: :service, prefix: true
  
  # Методы
  def total_price
    price * quantity
  end
end
