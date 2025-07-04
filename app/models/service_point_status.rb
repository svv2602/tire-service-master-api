class ServicePointStatus < ApplicationRecord
  # Связи
  has_many :service_points, foreign_key: 'status_id', dependent: :restrict_with_error
  
  # Валидации
  validates :name, presence: true, uniqueness: true
  
  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :sorted, -> { order(sort_order: :asc) }
  
  # ПРИМЕЧАНИЕ: Методы ниже устарели после миграции на новую систему статусов (is_active + work_status)
  # Оставлены для обратной совместимости, но не должны использоваться в новом коде
  
  # def self.active_id
  #   find_by(name: 'active')&.id
  # end
  # 
  # def self.temporarily_closed_id
  #   find_by(name: 'temporarily_closed')&.id
  # end
  # 
  # def self.closed_id
  #   find_by(name: 'closed')&.id
  # end
  # 
  # def self.maintenance_id
  #   find_by(name: 'maintenance')&.id
  # end
end
