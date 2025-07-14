class Region < ApplicationRecord
  # Связи
  has_many :cities, dependent: :destroy
  
  # Валидации
  validates :name, presence: true, uniqueness: true
  validates :code, uniqueness: true, allow_nil: true
  validates :name_ru, presence: true
  validates :name_uk, presence: true
  
  # Скоупы
  scope :active, -> { where(is_active: true) }
  
  # Методы локализации
  def localized_name(locale = 'ru')
    case locale.to_s
    when 'uk'
      name_uk.presence || name_ru.presence || name
    when 'ru'
      name_ru.presence || name_uk.presence || name
    else
      name_ru.presence || name_uk.presence || name
    end
  end
  
  def cities_count
    cities.count
  end
  
  def as_json(options = {})
    super(options).merge(
      'cities_count' => cities_count
    )
  end
end
