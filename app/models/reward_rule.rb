# Модель правил вознаграждений
class RewardRule < ApplicationRecord
  # Связи
  belongs_to :partner_supplier_agreement
  has_many :partner_rewards, dependent: :destroy
  
  # Делегирование для удобства
  delegate :partner, :supplier, to: :partner_supplier_agreement
  
  # Константы типов правил
  RULE_TYPES = {
    'fixed_per_order' => 'Фиксированная сумма за заказ',
    'percentage' => 'Процент от суммы заказа',
    'fixed_per_item' => 'Фиксированная сумма за единицу товара'
  }.freeze
  
  # Валидации
  validates :rule_type, presence: true, inclusion: { in: RULE_TYPES.keys }
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :priority, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :conditions_must_be_valid_json, if: -> { conditions.present? }
  
  # Скоупы
  scope :active, -> { where(active: true) }
  scope :by_rule_type, ->(type) { where(rule_type: type) }
  scope :by_priority, -> { order(:priority, :created_at) }
  scope :for_agreement, ->(agreement_id) { where(partner_supplier_agreement_id: agreement_id) }
  
  # Методы
  def rule_type_display
    RULE_TYPES[rule_type] || rule_type
  end
  
  def amount_display
    case rule_type
    when 'percentage'
      "#{amount}%"
    when 'fixed_per_order', 'fixed_per_item'
      "#{amount} грн"
    else
      amount.to_s
    end
  end
  
  def conditions_hash
    return {} if conditions.blank?
    
    begin
      JSON.parse(conditions)
    rescue JSON::ParserError
      {}
    end
  end
  
  def conditions_hash=(hash)
    self.conditions = hash.to_json if hash.present?
  end
  
  # Проверяет, применимо ли правило к заказу
  def applies_to_order?(order_data)
    return false unless active?
    
    conditions_obj = conditions_hash
    return true if conditions_obj.empty?
    
    # Проверка условий по брендам
    if conditions_obj['brands'].present?
      brand_names = extract_brand_names_from_order(order_data)
      brands_match = check_brands_condition(brand_names, conditions_obj['brands'], conditions_obj['exclude_brands'])
      return false unless brands_match
    end
    
    # Проверка условий по диаметрам
    if conditions_obj['diameters'].present?
      diameters = extract_diameters_from_order(order_data)
      diameters_match = check_diameters_condition(diameters, conditions_obj['diameters'], conditions_obj['exclude_diameters'])
      return false unless diameters_match
    end
    
    # Проверка минимальной суммы заказа
    if conditions_obj['min_order_amount'].present?
      order_amount = order_data.respond_to?(:total_amount) ? order_data.total_amount : 0
      return false if order_amount < conditions_obj['min_order_amount'].to_f
    end
    
    true
  end
  
  # Рассчитывает вознаграждение для заказа
  def calculate_reward(order_data)
    return 0 unless applies_to_order?(order_data)
    
    case rule_type
    when 'fixed_per_order'
      amount
    when 'percentage'
      order_amount = order_data.respond_to?(:total_amount) ? order_data.total_amount : 0
      (order_amount * amount / 100).round(2)
    when 'fixed_per_item'
      items_count = calculate_applicable_items_count(order_data)
      amount * items_count
    else
      0
    end
  end
  
  def conditions_description
    conditions_obj = conditions_hash
    return 'Все заказы' if conditions_obj.empty?
    
    parts = []
    
    if conditions_obj['brands'].present?
      brands_text = conditions_obj['exclude_brands'] ? 'Исключая бренды' : 'Только бренды'
      parts << "#{brands_text}: #{conditions_obj['brands'].join(', ')}"
    end
    
    if conditions_obj['diameters'].present?
      diameters_text = conditions_obj['exclude_diameters'] ? 'Исключая диаметры' : 'Только диаметры'
      parts << "#{diameters_text}: #{conditions_obj['diameters'].join(', ')}"
    end
    
    if conditions_obj['min_order_amount'].present?
      parts << "Минимальная сумма: #{conditions_obj['min_order_amount']} грн"
    end
    
    parts.join('; ')
  end
  
  private
  
  def conditions_must_be_valid_json
    return if conditions.blank?
    
    begin
      JSON.parse(conditions)
    rescue JSON::ParserError
      errors.add(:conditions, 'должны быть в формате JSON')
    end
  end
  
  def extract_brand_names_from_order(order_data)
    if order_data.is_a?(TireOrder)
      # Заказ через корзину
      order_data.tire_order_items.includes(supplier_tire_product: :tire_brand)
                .map(&:supplier_tire_product)
                .map { |product| product.tire_brand&.name || product.original_brand }
                .compact.uniq
    elsif order_data.is_a?(Order)
      # Заказ от интернет-магазина - пока возвращаем пустой массив
      # TODO: добавить извлечение брендов из OrderItem
      []
    else
      []
    end
  end
  
  def extract_diameters_from_order(order_data)
    if order_data.is_a?(TireOrder)
      # Заказ через корзину
      order_data.tire_order_items.includes(:supplier_tire_product)
                .map(&:supplier_tire_product)
                .map(&:diameter)
                .compact.uniq
    elsif order_data.is_a?(Order)
      # Заказ от интернет-магазина - пока возвращаем пустой массив
      # TODO: добавить извлечение диаметров из OrderItem
      []
    else
      []
    end
  end
  
  def check_brands_condition(brand_names, condition_brands, exclude = false)
    overlap = (brand_names & condition_brands).any?
    exclude ? !overlap : overlap
  end
  
  def check_diameters_condition(diameters, condition_diameters, exclude = false)
    overlap = (diameters.map(&:to_s) & condition_diameters.map(&:to_s)).any?
    exclude ? !overlap : overlap
  end
  
  def calculate_applicable_items_count(order_data)
    if order_data.is_a?(TireOrder)
      # Для заказов через корзину - считаем общее количество товаров
      order_data.tire_order_items.sum(:quantity)
    elsif order_data.is_a?(Order)
      # Для заказов интернет-магазинов - общее количество
      order_data.total_quantity || 0
    else
      0
    end
  end
end