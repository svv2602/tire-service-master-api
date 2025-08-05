class TireOrderItem < ApplicationRecord
  # Связи
  belongs_to :tire_order
  belongs_to :supplier_tire_product

  # Валидации
  validates :quantity, presence: true, numericality: { 
    greater_than: 0, 
    less_than_or_equal_to: 1000,
    only_integer: true 
  }
  validates :price_at_order, presence: true, numericality: { greater_than: 0 }
  
  # Уникальность товара в рамках одного заказа
  validates :supplier_tire_product_id, uniqueness: { 
    scope: :tire_order_id, 
    message: 'уже добавлен в этот заказ' 
  }

  # Коллбэки
  before_validation :set_price_at_order, on: :create
  after_save :update_order_total
  after_destroy :update_order_total

  # Делегирование методов
  delegate :brand, :model, :name, :size, :season, :image_url, :product_url, 
           :in_stock, :stock_status, to: :supplier_tire_product, prefix: :product
  delegate :supplier, to: :supplier_tire_product

  # Методы экземпляра
  def total_price
    quantity * price_at_order
  end

  def formatted_price_at_order
    return 'Не указана' unless price_at_order
    "#{price_at_order.to_f} UAH"
  end

  def formatted_total_price
    "#{total_price.to_f} UAH"
  end

  def product_display_name
    "#{product_brand} #{product_model}"
  end

  def product_full_info
    "#{product_display_name} #{product_size}"
  end

  # Проверка доступности товара
  def product_available?
    supplier_tire_product.present? && supplier_tire_product.in_stock
  end

  def product_availability_message
    return 'Товар доступен' if product_available?
    return 'Товар удален из каталога' unless supplier_tire_product.present?
    'Товар временно недоступен'
  end

  private

  def set_price_at_order
    return if price_at_order.present?
    
    if supplier_tire_product&.price_uah.present?
      self.price_at_order = supplier_tire_product.price_uah
    else
      errors.add(:price_at_order, 'не может быть определена - товар без цены')
      throw :abort
    end
  end

  def update_order_total
    tire_order.save! if tire_order.present?
  end
end