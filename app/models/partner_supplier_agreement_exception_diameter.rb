# Модель связи исключений с диаметрами шин (many-to-many)
class PartnerSupplierAgreementExceptionDiameter < ApplicationRecord
  # Ассоциации
  belongs_to :partner_supplier_agreement_exception, class_name: 'PartnerSupplierAgreementException'
  
  # Валидации
  validates :tire_diameter, presence: true, uniqueness: { 
    scope: :partner_supplier_agreement_exception_id,
    message: 'Диаметр уже добавлен к этому исключению'
  }
  validates :tire_diameter, format: { 
    with: /\A\d+\z/, 
    message: 'Диаметр должен содержать только цифры' 
  }
  
  # Скоупы  
  scope :by_diameter, ->(diameter) { where(tire_diameter: diameter) }
  scope :ordered, -> { order(:tire_diameter) }
  
  # Методы
  def formatted_diameter
    "#{tire_diameter}\""
  end
  
  def self.popular_diameters
    %w[13 14 15 16 17 18 19 20 21 22]
  end
  
  def self.validate_diameter(diameter)
    popular_diameters.include?(diameter.to_s)
  end
end