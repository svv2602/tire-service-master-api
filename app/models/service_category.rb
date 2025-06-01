class ServiceCategory < ApplicationRecord
  # Связи
  has_many :services, foreign_key: 'category_id', dependent: :restrict_with_error
  
  # Валидации
  validates :name, presence: true, uniqueness: true
  
  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :sorted, -> { order(sort_order: :asc) }
  
  # Методы
  def services_count
    services.count
  end
  
  def as_json(options = {})
    json = super(options)
    if options[:include_services_count]
      json['services_count'] = services_count
    end
    json
  end
end
