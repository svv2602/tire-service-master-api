# Единая корзина пользователя для товаров от разных поставщиков
class TireCart < ApplicationRecord
  # Связи
  belongs_to :user, optional: true  # Позволяем гостевые корзины без пользователя
  has_many :tire_cart_items, dependent: :destroy
  has_many :supplier_tire_products, through: :tire_cart_items

  # Валидации
  validates :user_id, uniqueness: true, allow_nil: true  # Разрешаем null для гостевых корзин

  # Скоупы
  scope :with_items, -> { joins(:tire_cart_items) }
  scope :recent, -> { order(updated_at: :desc) }

  # Методы экземпляра
  def total_items_count
    tire_cart_items.sum(:quantity)
  end

  def total_amount
    tire_cart_items.sum { |item| item.quantity * item.current_price }
  end

  def formatted_total
    "#{total_amount.to_f} UAH"
  end

  def formatted_total_amount
    "#{total_amount.to_f} ₴"
  end

  def empty?
    tire_cart_items.empty?
  end

  def suppliers
    Supplier.joins(:supplier_tire_products)
            .joins("JOIN tire_cart_items ON supplier_tire_products.id = tire_cart_items.supplier_tire_product_id")
            .where("tire_cart_items.tire_cart_id = ?", id)
            .distinct
  end

  def items_by_supplier
    items_with_suppliers = tire_cart_items.includes(supplier_tire_product: :supplier)
    
    items_with_suppliers.group_by { |item| item.supplier_tire_product.supplier }
  end

  def supplier_totals
    items_by_supplier.transform_values do |items|
      {
        items_count: items.sum(&:quantity),
        total_amount: items.sum { |item| item.quantity * item.current_price },
        items: items
      }
    end
  end

  # Добавление товара в корзину
  def add_product(supplier_tire_product, quantity = 1)
    existing_item = tire_cart_items.find_by(supplier_tire_product: supplier_tire_product)
    
    if existing_item
      existing_item.quantity += quantity
      existing_item.save!
    else
      tire_cart_items.create!(
        supplier_tire_product: supplier_tire_product,
        quantity: quantity,
        price_at_add: supplier_tire_product.price_uah
      )
    end
    
    touch # Обновляем updated_at
  end

  # Обновление количества товара
  def update_item_quantity(supplier_tire_product, quantity)
    item = tire_cart_items.find_by(supplier_tire_product: supplier_tire_product)
    return false unless item

    if quantity <= 0
      item.destroy!
    else
      item.update!(quantity: quantity)
    end
    
    touch
    true
  end

  # Удаление товара
  def remove_product(supplier_tire_product)
    item = tire_cart_items.find_by(supplier_tire_product: supplier_tire_product)
    return false unless item

    item.destroy!
    touch
    true
  end

  # Очистка корзины
  def clear!
    tire_cart_items.destroy_all
    touch
  end

  # Создание заказов для каждого поставщика
  def create_orders!(client_name:, client_phone:, comments_by_supplier: {})
    return [] if empty?

    created_orders = []
    
    ActiveRecord::Base.transaction do
      items_by_supplier.each do |supplier, items|
        # Создаем заказ для поставщика
        order = TireOrder.create!(
          user: user,
          supplier: supplier,
          status: 'submitted',
          client_name: client_name,
          client_phone: client_phone,
          comment: comments_by_supplier[supplier.id.to_s] || '',
          total_amount: 0 # Будет пересчитано автоматически
        )

        # Переносим товары из корзины в заказ
        items.each do |cart_item|
          order.tire_order_items.create!(
            supplier_tire_product: cart_item.supplier_tire_product,
            quantity: cart_item.quantity,
            price_at_order: cart_item.current_price
          )
        end

        created_orders << order
      end

      # Очищаем корзину после создания заказов
      clear!
    end

    created_orders
  end

  # Методы класса
  def self.find_or_create_for_user(user)
    find_by(user: user) || create!(user: user)
  end
end