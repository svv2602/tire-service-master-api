# Модель заказов от интернет-магазинов для сервисных точек
class Order < ApplicationRecord
  # Связи
  belongs_to :service_point
  has_many :order_items, dependent: :destroy
  
  # Валидации
  validates :status, presence: true, inclusion: { in: %w[received processing ready delivered canceled] }
  validates :ttn, presence: true, uniqueness: true
  validates :customer_name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :customer_phone, presence: true, format: { with: /\A\+?[\d\s\-\(\)]{10,15}\z/ }
  validates :point_name, presence: true
  validates :point_id, presence: true
  validates :bas_id, presence: true
  validates :order_date, presence: true
  validates :total_amount, presence: true, numericality: { greater_than: 0 }
  validates :total_quantity, presence: true, numericality: { greater_than: 0 }
  
  # Enum для статусов заказа
  enum :status, {
    received: 'received',          # Получен
    processing: 'processing',      # В обработке
    ready: 'ready',               # Готов к выдаче
    delivered: 'delivered',       # Выдан
    canceled: 'canceled'          # Отменен
  }, prefix: true
  
  # Scope для фильтрации
  scope :by_status, ->(status) { where(status: status) }
  scope :by_service_point, ->(service_point_id) { where(service_point_id: service_point_id) }
  scope :by_date_range, ->(from, to) { where(order_date: from..to) }
  scope :by_customer_phone, ->(phone) { where(customer_phone: phone) }
  scope :search_by_ttn, ->(ttn) { where("ttn ILIKE ?", "%#{ttn}%") }
  scope :search_by_customer, ->(query) { where("customer_name ILIKE ?", "%#{query}%") }
  
  # Методы для работы со статусами
  def can_mark_as_ready?
    received? || processing?
  end
  
  def can_mark_as_delivered?
    ready?
  end
  
  def can_cancel?
    !delivered? && !canceled?
  end
  
  # Автоматический расчет общих показателей при создании
  before_save :calculate_totals
  
  private
  
  def calculate_totals
    return unless order_items.loaded? || order_items.any?
    
    self.total_quantity = order_items.sum(:quantity)
    self.total_amount = order_items.sum { |item| item.quantity * item.price }
  end
end 