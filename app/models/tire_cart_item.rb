# Товар в корзине пользователя
class TireCartItem < ApplicationRecord
  # Связи
  belongs_to :tire_cart
  belongs_to :supplier_tire_product

  # Валидации
  validates :quantity, presence: true, numericality: { 
    greater_than: 0, 
    less_than_or_equal_to: 1000,
    only_integer: true 
  }
  validates :price_at_add, presence: true, numericality: { greater_than: 0 }
  
  # Уникальность товара в рамках одной корзины
  validates :supplier_tire_product_id, uniqueness: { 
    scope: :tire_cart_id, 
    message: 'уже добавлен в корзину' 
  }

  # Коллбэки
  before_validation :set_price_at_add, on: :create
  after_save :touch_cart
  after_destroy :touch_cart

  # Делегирование методов
  delegate :brand, :model, :name, :tire_size, :season, :image_url, :product_url, 
           :in_stock, :stock_status, to: :supplier_tire_product, prefix: :product
  delegate :supplier, to: :supplier_tire_product
  
  # Алиас для удобства группировки
  def product_supplier
    supplier_tire_product.supplier
  end

  # Методы экземпляра
  def current_price
    # Используем текущую цену товара или цену на момент добавления
    supplier_tire_product.price_uah || price_at_add
  end

  def total_price
    quantity * current_price
  end

  def formatted_price
    "#{price_at_add.to_f} ₴"
  end

  def formatted_total_price
    "#{total_price.to_f} ₴"
  end

  def price_changed?
    current_price != price_at_add
  end

  def price_change_info
    return nil unless price_changed?
    
    change = current_price - price_at_add
    change_percent = ((change / price_at_add) * 100).round(2)
    
    {
      old_price: price_at_add.to_f,
      new_price: current_price.to_f,
      change: change.to_f,
      change_percent: change_percent,
      increased: change > 0
    }
  end

  def product_available?
    supplier_tire_product.in_stock
  end

  def product_availability_message
    product_available? ? 'В наличии' : 'Нет в наличии'
  end

  def product_display_name
    "#{product_brand} #{product_model}"
  end

  def product_full_info
    "#{product_display_name} #{product_tire_size}"
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

  # Проверка изменения цены
  def price_changed?
    return false unless supplier_tire_product.price_uah.present?
    (supplier_tire_product.price_uah - price_at_add).abs > 0.01
  end

  def price_change_info
    return nil unless price_changed?
    
    current = supplier_tire_product.price_uah
    old = price_at_add
    change = current - old
    
    {
      old_price: old,
      new_price: current,
      change: change,
      change_percent: ((change / old) * 100).round(2),
      increased: change > 0
    }
  end

  private

  def set_price_at_add
    return if price_at_add.present?
    
    if supplier_tire_product&.price_uah.present?
      self.price_at_add = supplier_tire_product.price_uah
    else
      errors.add(:price_at_add, 'не может быть определена - товар без цены')
      throw :abort
    end
  end

  def touch_cart
    tire_cart.touch if tire_cart.present?
  end
end