class City < ApplicationRecord
  include CacheVersioning

  # Связи
  belongs_to :region
  has_many :service_points, dependent: :restrict_with_error

  # Валидации
  validates :name, presence: true
  validates :name, uniqueness: { scope: :region_id }
  validates :name_ru, presence: true
  validates :name_uk, presence: true

  # Cache invalidation on data changes
  after_commit :increment_cache_version

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
  
  def full_name(locale = 'ru')
    "#{localized_name(locale)}, #{region.localized_name(locale)}"
  end
end
