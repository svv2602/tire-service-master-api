class ServiceCategory < ApplicationRecord
  include CacheVersioning

  # Связи
  has_many :services, foreign_key: 'category_id', dependent: :restrict_with_error
  has_many :service_posts, dependent: :restrict_with_error

  # Валидации
  validates :name, presence: true, uniqueness: true
  validates :name_uk, presence: true

  # Cache invalidation on data changes
  after_commit :increment_cache_version

  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :sorted, -> { order(sort_order: :asc) }
  
  # Методы локализации
  def localized_name(locale = 'ru')
    case locale.to_s
    when 'uk'
      name_uk.presence || name.presence || ''
    when 'ru'
      name.presence || name_uk.presence || ''
    else
      name.presence || name_uk.presence || ''
    end
  end
  
  def localized_description(locale = 'ru')
    case locale.to_s
    when 'uk'
      description_uk.presence || description.presence || ''
    when 'ru'
      description.presence || description_uk.presence || ''
    else
      description.presence || description_uk.presence || ''
    end
  end
  
  # Методы
  def services_count
    services.count
  end
  
  def as_json(options = {})
    json = super(options)
    if options[:include_services_count]
      json['services_count'] = services_count
    end
    # Добавляем локализованные поля если указана локаль
    if options[:locale]
      json['localized_name'] = localized_name(options[:locale])
      json['localized_description'] = localized_description(options[:locale])
    end
    json
  end
end
