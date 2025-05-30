class ClientCar < ApplicationRecord
  # Связи
  belongs_to :client
  belongs_to :brand, class_name: 'CarBrand', foreign_key: 'brand_id'
  belongs_to :model, class_name: 'CarModel', foreign_key: 'model_id'
  belongs_to :tire_type, optional: true
  belongs_to :car_type, optional: true
  has_many :bookings, foreign_key: 'car_id', dependent: :nullify
  
  # Валидации
  validates :brand_id, presence: true
  validates :model_id, presence: true
  validates :year, numericality: { only_integer: true, greater_than: 1900, less_than_or_equal_to: -> { Date.current.year + 1 } }, allow_nil: true
  
  # Уникальность primary для клиента
  validate :only_one_primary_per_client
  
  # Скоупы
  scope :primary, -> { where(is_primary: true) }
  
  # Методы
  def full_name
    result = "#{brand.name} #{model.name}"
    result += " (#{year})" if year.present?
    result
  end
  
  def mark_as_primary!
    return if is_primary?
    
    ClientCar.transaction do
      client.cars.primary.update_all(is_primary: false)
      update!(is_primary: true)
    end
  end
  
  private
  
  def only_one_primary_per_client
    if is_primary && client.present? && client.cars.where.not(id: id).exists?(is_primary: true)
      errors.add(:is_primary, 'может быть только один основной автомобиль')
    end
  end
end
