# frozen_string_literal: true

# Модель справочника моделей шин
class TireModel < ApplicationRecord
  # Ассоциации
  belongs_to :tire_brand
  has_many :supplier_tire_products, dependent: :restrict_with_error

  # Валидации
  validates :name, presence: true, length: { maximum: 255 }
  validates :normalized_name, presence: true, length: { maximum: 255 }
  validates :rating_score, inclusion: { in: 1..10 }
  validates :season_type, inclusion: { in: ['summer', 'winter', 'all_season'] }, allow_blank: true
  # aliases не требует отдельной валидации, так как это массив

  # Уникальность модели в рамках бренда
  validates :normalized_name, uniqueness: { scope: :tire_brand_id }

  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :by_rating, ->(min_rating) { where('rating_score >= ?', min_rating) }
  scope :by_season, ->(season) { where(season_type: season) }
  scope :by_brand, ->(brand_id) { where(tire_brand_id: brand_id) }

  # Callbacks
  before_save :normalize_name
  before_save :clean_aliases

  class << self
    # Поиск модели по названию или алиасу в рамках бренда
    def find_by_name_or_alias(name, brand_id = nil)
      return nil if name.blank?
      
      normalized = normalize_string(name)
      scope = brand_id ? where(tire_brand_id: brand_id) : all
      
      # Точное совпадение по нормализованному названию
      model = scope.find_by(normalized_name: normalized)
      return model if model
      
      # Поиск по алиасам
      scope.where("? = ANY(aliases)", normalized).first ||
      scope.where("? ILIKE ANY(aliases)", "%#{normalized}%").first
    end

    # Создание или поиск модели с автоматической нормализацией
    def find_or_create_by_name(name, brand_id, season_type = nil)
      return nil if name.blank? || brand_id.blank?
      
      model = find_by_name_or_alias(name, brand_id)
      return model if model
      
      # Создаем новую модель с базовыми параметрами
      create!(
        tire_brand_id: brand_id,
        name: name.titleize,
        normalized_name: normalize_string(name),
        rating_score: determine_default_rating(name, brand_id),
        season_type: season_type,
        aliases: [normalize_string(name)]
      )
    end

    # Получение топ моделей для бренда
    def top_models_for_brand(brand_id, limit: 5)
      by_brand(brand_id).active.order(rating_score: :desc, name: :asc).limit(limit)
    end

    private

    def normalize_string(str)
      str.to_s.strip.downcase.gsub(/[^\p{L}\p{N}\s]/, '').squeeze(' ')
    end

    def determine_default_rating(name, brand_id)
      # Определяем базовый рейтинг на основе известных моделей
      premium_models = ['pilot sport', 'пилот спорт', 'premium contact', 'премиум контакт', 
                       'p zero', 'п зеро', 'potenza', 'потенца']
      good_models = ['energy saver', 'энерджи сейвер', 'eco contact', 'эко контакт',
                    'cinturato', 'чинтурато', 'turanza', 'туранца']
      
      normalized = normalize_string(name)
      brand = TireBrand.find_by(id: brand_id)
      base_rating = brand&.rating_score || 5
      
      if premium_models.any? { |model| normalized.include?(model) }
        return [base_rating + 2, 10].min
      elsif good_models.any? { |model| normalized.include?(model) }
        return [base_rating + 1, 10].min
      end
      
      base_rating # Рейтинг бренда как базовый
    end
  end

  # Расчет рейтинга для системы оценки шин
  def rating_for_evaluation
    base_rating = rating_score
    
    # Бонус от рейтинга бренда
    brand_bonus = (tire_brand.rating_score - 5) * 0.2
    
    # Бонус за сезонную специализацию
    seasonal_bonus = season_type.present? ? 0.5 : 0
    
    final_rating = base_rating + brand_bonus + seasonal_bonus
    [final_rating, 10].min # Максимум 10 баллов
  end

  # Полное название модели с брендом
  def full_name
    "#{tire_brand.name} #{name}"
  end

  # Получение всех размеров для данной модели
  def available_sizes
    supplier_tire_products.distinct.pluck(:width, :height, :diameter)
                          .map { |w, h, d| "#{w}/#{h}R#{d}" }
                          .sort
  end

  private

  def normalize_name
    self.normalized_name = self.class.send(:normalize_string, name) if name.present?
  end

  def clean_aliases
    return unless aliases.present?
    
    self.aliases = aliases.map do |alias_name|
      self.class.send(:normalize_string, alias_name)
    end.compact.uniq.reject(&:blank?)
  end
end