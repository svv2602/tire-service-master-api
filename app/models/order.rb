# Модель заказов от интернет-магазинов для сервисных точек
class Order < ApplicationRecord
  # Связи
  belongs_to :service_point
  belongs_to :supplier, optional: true
  has_many :order_items, dependent: :destroy
  
  # Система вознаграждений
  has_many :partner_rewards, dependent: :destroy
  
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
  
  # Коллбэки для автоматического расчета вознаграждений
  after_update :calculate_partner_reward, if: :should_calculate_reward?
  
  # Методы для работы со статусами
  def can_mark_as_ready?
    status_received? || status_processing?
  end
  
  def can_mark_as_delivered?
    status_ready?
  end
  
  def can_cancel?
    !status_delivered? && !status_canceled?
  end
  
  # Человекочитаемое название статуса
  def status_label
    case status
    when 'received' then 'Получен'
    when 'processing' then 'В обработке'
    when 'ready' then 'Готов к выдаче'
    when 'delivered' then 'Выдан'
    when 'canceled' then 'Отменен'
    else status.humanize
    end
  end
  
  # Автоматический расчет общих показателей при создании
  before_save :calculate_totals
  
  private
  
  def calculate_totals
    return unless order_items.loaded? || order_items.any?
    
    self.total_quantity = order_items.sum(:quantity)
    self.total_amount = order_items.sum { |item| item.quantity * item.price }
  end
  
  # Определяет, нужно ли рассчитывать вознаграждение
  def should_calculate_reward?
    status_changed? && %w[received processing ready delivered].include?(status) && supplier.present?
  end
  
  # Рассчитывает вознаграждение партнера
  def calculate_partner_reward
    return unless service_point&.partner&.is_active?
    return unless supplier.present?
    
    service = RewardCalculationService.new(self)
    
    if service.reward_exists?
      service.recalculate_existing_reward
    else
      service.calculate_and_create_reward
    end
  rescue => e
    Rails.logger.error "Ошибка расчета вознаграждения для Order ##{ttn}: #{e.message}"
  end
end 