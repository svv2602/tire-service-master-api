# Модель связи исключений с брендами шин (many-to-many)
class PartnerSupplierAgreementExceptionBrand < ApplicationRecord
  # Ассоциации
  belongs_to :partner_supplier_agreement_exception, class_name: 'PartnerSupplierAgreementException'
  belongs_to :tire_brand, optional: true # Может быть nil, если бренд удален
  
  # Валидации
  validates :tire_brand_id, presence: true, uniqueness: { 
    scope: :partner_supplier_agreement_exception_id,
    message: 'Бренд уже добавлен к этому исключению'
  }
  
  # Скоупы
  scope :active_brands, -> { joins(:tire_brand).where(tire_brands: { is_active: true }) }
  scope :by_brand, ->(brand_id) { where(tire_brand_id: brand_id) }
  
  # Методы
  def brand_name
    tire_brand&.name || "Удаленный бренд (ID: #{tire_brand_id})"
  end
end