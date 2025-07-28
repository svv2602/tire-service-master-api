# Модель товаров в заказе
class OrderItem < ApplicationRecord
  # Связи
  belongs_to :order
  
  # Валидации
  validates :artikul, presence: true, length: { minimum: 1, maximum: 50 }
  validates :quantity, presence: true, numericality: { greater_than: 0, only_integer: true }
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :sum, presence: true, numericality: { greater_than: 0 }
  validates :bas_id, presence: true
  
  # Автоматический расчет суммы
  before_save :calculate_sum
  
  # Scope для поиска
  scope :by_artikul, ->(artikul) { where(artikul: artikul) }
  
  private
  
  def calculate_sum
    self.sum = quantity * price if quantity && price
  end
end 