# Модель исключений для договоренностей партнеров с поставщиками
class PartnerSupplierAgreementException < ApplicationRecord
  # Связи
  belongs_to :partner_supplier_agreement
  belongs_to :tire_brand, class_name: 'TireBrand', foreign_key: 'tire_brand_id', optional: true
  
  # Новые связи для множественного выбора
  has_many :exception_brands, class_name: 'PartnerSupplierAgreementExceptionBrand', dependent: :destroy
  has_many :tire_brands, through: :exception_brands
  has_many :exception_diameters, class_name: 'PartnerSupplierAgreementExceptionDiameter', dependent: :destroy
  
  # Валидации
  validates :exception_type, presence: true, 
            inclusion: { 
              in: %w[fixed_amount percentage], 
              message: 'должен быть одним из: fixed_amount, percentage' 
            }
  
  validates :application_scope, presence: true,
            inclusion: { 
              in: %w[per_order per_item], 
              message: 'должен быть одним из: per_order, per_item' 
            }
  
  validates :priority, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  
  # Условная валидация значений
  validates :exception_amount, presence: true, numericality: { greater_than: 0 }, if: :fixed_amount?
  validates :exception_percentage, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }, if: :percentage?
  
  validates :exception_amount, absence: true, if: :percentage?
  validates :exception_percentage, absence: true, if: :fixed_amount?
  
  # Валидация диаметра (должен быть числом)
  validates :tire_diameter, format: { with: /\A\d+(\.\d+)?\z/, message: 'должен быть числом' }, allow_blank: true
  
  # Скоупы
  scope :active, -> { where(active: true) }
  scope :by_brand, ->(brand_id) { where(tire_brand_id: brand_id) }
  scope :by_diameter, ->(diameter) { where(tire_diameter: diameter) }
  scope :by_priority, -> { order(priority: :desc, created_at: :asc) }
  scope :for_all_brands, -> { where(tire_brand_id: nil) }
  scope :for_all_diameters, -> { where(tire_diameter: nil) }
  
  # Методы проверки типа
  def fixed_amount?
    exception_type == 'fixed_amount'
  end
  
  def percentage?
    exception_type == 'percentage'
  end
  
  def per_order?
    application_scope == 'per_order'
  end
  
  def per_item?
    application_scope == 'per_item'
  end
  
  # Методы отображения
  def exception_type_text(locale = :ru)
    case exception_type
    when 'fixed_amount'
      locale == :ru ? 'Фиксированная сумма' : 'Фіксована сума'
    when 'percentage'
      locale == :ru ? 'Процент' : 'Відсоток'
    else
      exception_type
    end
  end
  
  def application_scope_text(locale = :ru)
    case application_scope
    when 'per_order'
      locale == :ru ? 'За весь заказ' : 'За весь замовлення'
    when 'per_item'
      locale == :ru ? 'За каждую единицу' : 'За кожну одиницю'
    else
      application_scope
    end
  end
  
  def tire_brand_text(locale = :ru)
    if tire_brand_id.nil?
      locale == :ru ? 'Все бренды' : 'Всі бренди'
    else
      tire_brand&.name || "ID: #{tire_brand_id}"
    end
  end
  
  def tire_diameter_text(locale = :ru)
    if tire_diameter.nil?
      locale == :ru ? 'Все диаметры' : 'Всі діаметри'
    else
      "#{tire_diameter}″"
    end
  end
  
  def value_text
    if fixed_amount?
      "#{exception_amount} грн"
    elsif percentage?
      "#{exception_percentage}%"
    else
      'Не указано'
    end
  end
  
  def full_description(locale = :ru)
    brand_text = tire_brand_text(locale)
    diameter_text = tire_diameter_text(locale)
    type_text = exception_type_text(locale)
    scope_text = application_scope_text(locale)
    
    "#{brand_text}, #{diameter_text}: #{type_text} #{value_text} (#{scope_text})"
  end
  
  # Проверяет, применимо ли исключение к товару
  def applies_to_item?(brand_id, diameter)
    return false unless active?
    
    # Проверка бренда
    if tire_brand_id.present? && tire_brand_id != brand_id
      return false
    end
    
    # Проверка диаметра
    if tire_diameter.present? && tire_diameter.to_s != diameter.to_s
      return false
    end
    
    true
  end
  
  # Рассчитывает размер вознаграждения
  def calculate_reward(base_amount, quantity = 1)
    return 0 unless active?
    
    if fixed_amount?
      if per_order?
        exception_amount
      else # per_item
        exception_amount * quantity
      end
    elsif percentage?
      if per_order?
        base_amount * (exception_percentage / 100.0)
      else # per_item
        (base_amount / quantity) * (exception_percentage / 100.0) * quantity
      end
    else
      0
    end
  end
  
  # Валидация применимости исключения
  def validate_applicability
    errors.add(:base, 'Исключение должно содержать условия применения') if tire_brand_id.nil? && tire_diameter.nil?
  end
  
  # === НОВЫЕ МЕТОДЫ ДЛЯ РАБОТЫ С МНОЖЕСТВЕННЫМИ БРЕНДАМИ И ДИАМЕТРАМИ ===
  
  # Получить все ID брендов в исключении (старый + новые)
  def all_brand_ids
    brand_ids = []
    brand_ids << tire_brand_id if tire_brand_id.present?
    brand_ids.concat(exception_brands.pluck(:tire_brand_id))
    brand_ids.uniq
  end
  
  # Получить все диаметры в исключении (старый + новые)  
  def all_diameters
    diameters = []
    diameters << tire_diameter if tire_diameter.present?
    diameters.concat(exception_diameters.pluck(:tire_diameter))
    diameters.uniq
  end
  
  # Добавить бренд к исключению
  def add_brand!(brand_id)
    return false if brand_id.blank?
    exception_brands.find_or_create_by(tire_brand_id: brand_id)
  end
  
  # Добавить диаметр к исключению
  def add_diameter!(diameter)
    return false if diameter.blank?
    exception_diameters.find_or_create_by(tire_diameter: diameter.to_s)
  end
  
  # Установить бренды (заменить все существующие)
  def set_brands!(brand_ids)
    exception_brands.destroy_all
    Array(brand_ids).each { |brand_id| add_brand!(brand_id) if brand_id.present? }
  end
  
  # Установить диаметры (заменить все существующие)
  def set_diameters!(diameters)
    exception_diameters.destroy_all
    Array(diameters).each { |diameter| add_diameter!(diameter) if diameter.present? }
  end
  
  # Проверить, применимо ли исключение к конкретному товару
  def applies_to_item_with_multiple?(brand_id: nil, diameter: nil)
    # Если нет брендов/диаметров в исключении, то применимо ко всем
    brand_match = all_brand_ids.empty? || all_brand_ids.include?(brand_id)
    diameter_match = all_diameters.empty? || all_diameters.include?(diameter&.to_s)
    
    brand_match && diameter_match
  end
  
  # Получить читаемое описание применимых брендов
  def brands_description(locale = :ru)
    brand_ids = all_brand_ids
    return (locale == :ru ? 'Все бренды' : 'Всі бренди') if brand_ids.empty?
    
    brand_names = TireBrand.where(id: brand_ids).pluck(:name)
    brand_names.join(', ')
  end
  
  # Получить читаемое описание применимых диаметров  
  def diameters_description(locale = :ru)
    diameters = all_diameters
    return (locale == :ru ? 'Все диаметры' : 'Всі діаметри') if diameters.empty?
    
    diameters.map { |d| "#{d}\"" }.join(', ')
  end
  
  # Обновленное полное описание с учетом множественности
  def full_description_with_multiple(locale = :ru)
    parts = []
    parts << exception_type_text(locale)
    parts << value_text
    parts << application_scope_text(locale)
    parts << brands_description(locale)
    parts << diameters_description(locale)
    
    parts.join(' | ')
  end
  
  private
  
  # Кастомная валидация для логической целостности
  validate :validate_exception_value_presence
  
  def validate_exception_value_presence
    if fixed_amount? && exception_amount.blank?
      errors.add(:exception_amount, 'должно быть указано для фиксированной суммы')
    elsif percentage? && exception_percentage.blank?
      errors.add(:exception_percentage, 'должен быть указан для процентного типа')
    end
  end
end