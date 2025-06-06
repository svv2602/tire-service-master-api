class Article < ApplicationRecord
  # Константы для категорий
  CATEGORIES = {
    'seasonal' => {
      name: 'Сезонные советы',
      description: 'Советы по смене резины по сезонам',
      icon: '🍂'
    },
    'tips' => {
      name: 'Полезные советы',
      description: 'Практические советы для автовладельцев',
      icon: '💡'
    },
    'maintenance' => {
      name: 'Обслуживание',
      description: 'Уход за шинами и дисками',
      icon: '🔧'
    },
    'selection' => {
      name: 'Выбор шин',
      description: 'Как выбрать правильные шины',
      icon: '🔍'
    },
    'safety' => {
      name: 'Безопасность',
      description: 'Безопасность на дороге',
      icon: '🛡️'
    },
    'reviews' => {
      name: 'Обзоры',
      description: 'Обзоры шин и оборудования',
      icon: '⭐'
    },
    'news' => {
      name: 'Новости',
      description: 'Новости автомобильного мира',
      icon: '📰'
    }
  }.freeze
  
  # Связи
  belongs_to :author, class_name: 'User'
  
  # Валидации
  validates :title, presence: true, length: { maximum: 255 }
  validates :content, presence: true
  validates :excerpt, length: { maximum: 500 }
  validates :category, presence: true, inclusion: { in: CATEGORIES.keys }
  validates :status, presence: true, inclusion: { in: %w[draft published archived] }
  validates :slug, uniqueness: true, allow_blank: true
  validates :meta_title, length: { maximum: 60 }
  validates :meta_description, length: { maximum: 160 }
  validates :reading_time, presence: true, numericality: { greater_than: 0 }
  
  # Колбеки
  before_validation :generate_slug, if: -> { title.present? && slug.blank? }
  before_validation :calculate_reading_time, if: -> { content_changed? }
  before_validation :set_published_at, if: -> { status_changed? && status == 'published' }
  before_validation :set_meta_fields, if: -> { title_changed? || excerpt_changed? }
  
  # Скоупы
  scope :published, -> { where(status: 'published') }
  scope :draft, -> { where(status: 'draft') }
  scope :featured, -> { where(featured: true) }
  scope :by_category, ->(category) { where(category: category) }
  scope :recent, -> { order(published_at: :desc, created_at: :desc) }
  scope :popular, -> { order(views_count: :desc) }
  scope :with_author, -> { includes(:author) }
  
  # Поиск
  scope :search, ->(query) {
    return all if query.blank?
    
    where(
      "title ILIKE ? OR content ILIKE ? OR excerpt ILIKE ?",
      "%#{query}%", "%#{query}%", "%#{query}%"
    )
  }
  
  # Методы экземпляра
  def published?
    status == 'published' && published_at&.past?
  end
  
  def draft?
    status == 'draft'
  end
  
  def category_info
    CATEGORIES[category] || {}
  end
  
  def category_name
    category_info[:name] || category.humanize
  end
  
  def increment_views!
    increment!(:views_count)
  end
  
  def estimated_reading_time
    return reading_time if reading_time.present?
    
    calculate_reading_time
    reading_time
  end
  
  def to_param
    slug.presence || id.to_s
  end
  
  def excerpt_or_truncated_content
    excerpt.presence || truncate_content(200)
  end
  
  def featured_image
    featured_image_url.presence || default_image_for_category
  end
  
  # Методы класса
  def self.categories_list
    CATEGORIES.map do |key, info|
      {
        key: key,
        name: info[:name],
        description: info[:description],
        icon: info[:icon]
      }
    end
  end
  
  def self.popular_categories
    joins("LEFT JOIN articles a2 ON articles.category = a2.category")
      .group(:category)
      .order('COUNT(a2.id) DESC')
      .limit(5)
      .pluck(:category)
  end
  
  def self.recent_by_category(category, limit = 5)
    published
      .by_category(category)
      .recent
      .limit(limit)
  end
  
  private
  
  def generate_slug
    return if title.blank?
    
    base_slug = title.parameterize
    self.slug = base_slug
    
    # Проверяем уникальность
    counter = 1
    while Article.exists?(slug: slug) && (new_record? || slug != slug_was)
      self.slug = "#{base_slug}-#{counter}"
      counter += 1
    end
  end
  
  def calculate_reading_time
    return unless content.present?
    
    # Примерно 200 слов в минуту для русского языка
    words_count = content.split.length
    self.reading_time = [(words_count / 200.0).ceil, 1].max
  end
  
  def set_published_at
    self.published_at = Time.current if status == 'published' && published_at.blank?
  end
  
  def set_meta_fields
    self.meta_title = title if meta_title.blank? && title.present?
    self.meta_description = excerpt if meta_description.blank? && excerpt.present?
  end
  
  def truncate_content(length)
    return '' if content.blank?
    
    plain_content = content.gsub(/<[^>]*>/, '') # Убираем HTML теги
    plain_content.length > length ? "#{plain_content[0...length]}..." : plain_content
  end
  
  def default_image_for_category
    # Можно добавить дефолтные изображения для каждой категории
    case category
    when 'seasonal'
      '/images/articles/seasonal-default.jpg'
    when 'tips'
      '/images/articles/tips-default.jpg'
    when 'maintenance'
      '/images/articles/maintenance-default.jpg'
    else
      '/images/articles/default.jpg'
    end
  end
end