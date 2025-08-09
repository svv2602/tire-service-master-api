# Модель договоренностей между партнерами и поставщиками
class PartnerSupplierAgreement < ApplicationRecord
  # Связи
  belongs_to :partner
  belongs_to :supplier
  has_many :reward_rules, dependent: :destroy
  has_many :partner_rewards, through: :reward_rules
  has_many :partner_supplier_agreement_exceptions, dependent: :destroy, class_name: 'PartnerSupplierAgreementException'
  has_many :exceptions, class_name: 'PartnerSupplierAgreementException', dependent: :destroy
  
  # Валидации
  validates :start_date, presence: true
  validates :commission_type, presence: true, 
            inclusion: { 
              in: %w[custom fixed_amount percentage], 
              message: 'должен быть одним из: custom, fixed_amount, percentage' 
            }
  validates :order_types, presence: true,
            inclusion: { 
              in: %w[cart_orders pickup_orders both], 
              message: 'должен быть одним из: cart_orders, pickup_orders, both' 
            }
  validates :partner_id, uniqueness: { 
    scope: :supplier_id, 
    message: 'уже имеет договоренности с этим поставщиком' 
  }
  validate :end_date_after_start_date, if: -> { end_date.present? }
  
  # Скоупы
  scope :active, -> { where(active: true) }
  scope :current, -> { where('start_date <= ? AND (end_date IS NULL OR end_date >= ?)', Date.current, Date.current) }
  scope :by_partner, ->(partner_id) { where(partner_id: partner_id) }
  scope :by_supplier, ->(supplier_id) { where(supplier_id: supplier_id) }
  scope :with_partner_and_supplier, -> { includes(:partner, :supplier) }
  
  # Методы
  def active?
    active && current?
  end
  
  def current?
    start_date <= Date.current && (end_date.nil? || end_date >= Date.current)
  end
  
  def display_name
    "#{partner.company_name} ↔ #{supplier.name}"
  end
  
  def duration_text
    if end_date.present?
      "#{start_date.strftime('%d.%m.%Y')} - #{end_date.strftime('%d.%m.%Y')}"
    else
      "с #{start_date.strftime('%d.%m.%Y')} (бессрочно)"
    end
  end
  
  def status_text
    return 'Неактивно' unless active?
    return 'Действует' if current?
    return 'Не начато' if start_date > Date.current
    'Завершено'
  end
  
  def can_be_edited?
    active? && current?
  end
  
  # Получить все активные правила с приоритетом
  def active_reward_rules
    reward_rules.where(active: true).order(:priority, :created_at)
  end
  
  # Получить применимое правило для заказа
  def applicable_rule_for_order(order_data)
    active_reward_rules.find do |rule|
      rule.applies_to_order?(order_data)
    end
  end
  
  # Методы для работы с типами заказов
  def order_types_text(locale = :ru)
    case order_types
    when 'cart_orders'
      locale == :ru ? 'Заказ товара' : 'Замовлення товару'
    when 'pickup_orders'
      locale == :ru ? 'Выдача товара' : 'Видача товару'
    when 'both'
      locale == :ru ? 'Оба типа' : 'Обидва типи'
    else
      order_types
    end
  end
  
  def supports_cart_orders?
    %w[cart_orders both].include?(order_types)
  end
  
  def supports_pickup_orders?
    %w[pickup_orders both].include?(order_types)
  end
  
  def active_text(locale = :ru)
    if active?
      locale == :ru ? 'Активна' : 'Активна'
    else
      locale == :ru ? 'Неактивна' : 'Неактивна'
    end
  end
  
  # Новые методы для работы с комиссией
  def commission_type_text(locale = :ru)
    case commission_type
    when 'fixed_amount'
      locale == :ru ? 'Фиксированная сумма' : 'Фіксована сума'
    when 'percentage'
      locale == :ru ? 'Процент от суммы' : 'Відсоток від суми'
    when 'custom'
      locale == :ru ? 'Индивидуальные правила' : 'Індивідуальні правила'
    else
      commission_type
    end
  end
  
  def commission_unit_text(locale = :ru)
    case commission_unit
    when 'per_order'
      locale == :ru ? 'За заказ' : 'За замовлення'
    when 'per_item'
      locale == :ru ? 'За единицу' : 'За одиницю'
    else
      commission_unit
    end
  end
  
  def commission_value_text
    case commission_type
    when 'fixed_amount'
      if commission_amount.present?
        "#{commission_amount} грн #{commission_unit_text}"
      else
        'Не указано'
      end
    when 'percentage'
      if commission_percentage.present?
        "#{commission_percentage}% #{commission_unit_text}"
      else
        'Не указано'
      end
    when 'custom'
      "#{active_exceptions.count} правил"
    else
      'Не указано'
    end
  end
  
  # Получить активные исключения
  def active_exceptions
    exceptions.active.by_priority
  end
  
  # Проверить, есть ли применимые исключения для товара
  def applicable_exception_for_item(brand_id, diameter)
    active_exceptions.find { |exception| exception.applies_to_item?(brand_id, diameter) }
  end
  
  # Рассчитать вознаграждение с учетом исключений
  def calculate_reward_with_exceptions(base_amount, items_data = [])
    return 0 unless active? && current?
    
    total_reward = 0
    
    if commission_type == 'custom'
      # Используем только исключения
      items_data.each do |item|
        exception = applicable_exception_for_item(item[:brand_id], item[:diameter])
        if exception
          total_reward += exception.calculate_reward(item[:amount], item[:quantity])
        end
      end
    else
      # Базовое вознаграждение
      base_reward = calculate_base_reward(base_amount, items_data.sum { |item| item[:quantity] })
      
      # Применяем исключения
      exception_reward = 0
      items_data.each do |item|
        exception = applicable_exception_for_item(item[:brand_id], item[:diameter])
        if exception
          exception_reward += exception.calculate_reward(item[:amount], item[:quantity])
        end
      end
      
      total_reward = exception_reward > 0 ? exception_reward : base_reward
    end
    
    total_reward
  end
  
  private
  
  def calculate_base_reward(base_amount, total_quantity)
    case commission_type
    when 'fixed_amount'
      if commission_unit == 'per_order'
        commission_amount || 0
      else # per_item
        (commission_amount || 0) * total_quantity
      end
    when 'percentage'
      (base_amount * (commission_percentage || 0) / 100.0)
    else
      0
    end
  end
  
  def end_date_after_start_date
    return unless start_date.present? && end_date.present?
    
    if end_date <= start_date
      errors.add(:end_date, 'должна быть позже даты начала')
    end
  end
end