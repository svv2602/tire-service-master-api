class ServicePointCategorySetting < ApplicationRecord
  # Связи
  belongs_to :service_point
  belongs_to :service_category
  
  # Валидации
  validates :auto_confirmation, inclusion: { in: [true, false] }
  validates :service_point_id, presence: true
  validates :service_category_id, presence: true
  validates :service_point_id, uniqueness: { 
    scope: :service_category_id, 
    message: 'Настройка для данной комбинации точки и категории уже существует' 
  }
  
  # Скоупы
  scope :with_auto_confirmation, -> { where(auto_confirmation: true) }
  scope :with_manual_confirmation, -> { where(auto_confirmation: false) }
  scope :for_service_point, ->(service_point_id) { where(service_point_id: service_point_id) }
  scope :for_category, ->(category_id) { where(service_category_id: category_id) }
  
  # Методы класса
  def self.auto_confirmation_for(service_point_id, category_id)
    setting = find_by(service_point_id: service_point_id, service_category_id: category_id)
    setting&.auto_confirmation || false # По умолчанию требуем ручное подтверждение
  end
  
  def self.set_auto_confirmation(service_point_id, category_id, enabled)
    setting = find_or_initialize_by(
      service_point_id: service_point_id, 
      service_category_id: category_id
    )
    setting.auto_confirmation = enabled
    setting.save!
    setting
  end
  
  # Методы экземпляра
  def auto_confirmation_enabled?
    auto_confirmation == true
  end
  
  def manual_confirmation_required?
    auto_confirmation == false
  end
end 