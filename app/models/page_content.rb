class PageContent < ApplicationRecord
  # Подключение Active Storage для загрузки файлов
  has_one_attached :image
  has_many_attached :gallery_images
  
  # Сериализация настроек
  serialize :settings, coder: JSON
  
  # Константы языков
  SUPPORTED_LANGUAGES = %w[uk ru].freeze
  
  # Валидации
  validates :section, presence: true
  validates :content_type, presence: true
  validates :title, presence: true, length: { maximum: 255 }
  validates :content, presence: true
  validates :position, presence: true, numericality: { greater_than: 0 }
  validates :active, inclusion: { in: [true, false] }
  validates :language, presence: true, inclusion: { in: SUPPORTED_LANGUAGES }
  
  # Валидация уникальности позиции в рамках секции, типа контента и языка
  validates :position, uniqueness: { 
    scope: [:section, :content_type, :language], 
    message: 'должна быть уникальной в рамках секции, типа контента и языка' 
  }
  
  # Скоупы
  scope :active, -> { where(active: true) }
  scope :by_section, ->(section) { where(section: section) }
  scope :by_content_type, ->(type) { where(content_type: type) }
  scope :by_language, ->(lang) { where(language: lang) }
  scope :ordered, -> { order(:position) }
  scope :search, ->(query) { 
    where('title ILIKE ? OR content ILIKE ?', "%#{query}%", "%#{query}%") 
  }
  
  # Методы для работы с изображениями
  def image_url
    return nil unless image.attached?
    Rails.application.routes.url_helpers.rails_blob_url(image, only_path: true)
  end

  def gallery_image_urls
    return [] unless gallery_images.attached?
    gallery_images.map do |img|
      Rails.application.routes.url_helpers.rails_blob_url(img, only_path: true)
    end
  end

  # Методы для работы с динамическими данными
  def dynamic_data
    case content_type
    when 'service'
      get_service_data
    when 'city'
      get_city_data
    when 'article'
      get_article_data
    else
      nil
    end
  end

  # Методы для получения доступных полей настроек
  def available_settings_fields
    case content_type
    when 'hero'
      %w[subtitle button_text search_placeholder city_placeholder]
    when 'text_block'
      %w[type alignment]
    when 'service'
      %w[category icon]
    when 'city'
      %w[region service_points_count]
    when 'article'
      %w[read_time author category]
    when 'cta'
      %w[primary_button_text secondary_button_text]
    when 'footer'
      %w[contact_info social_links services_links info_links copyright]
    else
      []
    end
  end

  # Методы для получения названий
  def content_type_name
    case content_type
    when 'hero' then 'Героїчна секція'
    when 'text_block' then 'Текстовий блок'
    when 'service' then 'Послуга'
    when 'city' then 'Місто'
    when 'article' then 'Стаття'
    when 'cta' then 'Заклик до дії'
    when 'footer' then 'Підвал'
    else content_type.humanize
    end
  end

  def section_name
    case section
    when 'client_main' then 'Головна сторінка клієнта'
    when 'admin_dashboard' then 'Панель адміністратора'
    when 'partner_portal' then 'Портал партнера'
    when 'knowledge_base' then 'База знань'
    when 'about' then 'Про нас'
    when 'contacts' then 'Контакти'
    else section.humanize
    end
  end

  def language_name
    case language
    when 'uk' then 'Українська'
    when 'ru' then 'Русский'
    else language
    end
  end

  private

  def get_service_data
    return nil unless settings['category']
    
    Service.where(is_active: true)
           .where('category ILIKE ?', "%#{settings['category']}%")
           .limit(8)
           .select(:id, :name, :description, :category, :icon)
  end

  def get_city_data
    City.joins(:service_points)
        .where(is_active: true, service_points: { is_active: true, work_status: 'working' })
        .group('cities.id')
        .select('cities.*, COUNT(service_points.id) as service_points_count')
        .limit(10)
  end

  def get_article_data
    Article.where(status: 'published')
           .includes(:author)
           .order(published_at: :desc)
           .limit(6)
           .select(:id, :title, :excerpt, :category, :reading_time, :author_id, :published_at, :slug)
  end
end
