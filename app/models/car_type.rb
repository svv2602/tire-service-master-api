class CarType < ApplicationRecord
  # Связи
  has_many :bookings, dependent: :restrict_with_error
  has_many :client_cars, dependent: :nullify
  
  # Валидации
  validates :name, presence: true, uniqueness: true
  
  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :alphabetical, -> { order(:name) }
  
  # Методы для локализации
  def localized_name(locale = I18n.locale)
    case locale.to_s
    when 'uk'
      name_uk.present? ? name_uk : name
    else
      name
    end
  end
  
  def localized_description(locale = I18n.locale)
    case locale.to_s
    when 'uk'
      description_uk.present? ? description_uk : description
    else
      description
    end
  end
end
