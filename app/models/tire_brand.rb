# frozen_string_literal: true

# Модель справочника брендов шин
class TireBrand < ApplicationRecord
  include CacheVersioning

  # Ассоциации
  belongs_to :country, optional: true
  has_many :tire_models, dependent: :destroy
  has_many :supplier_tire_products, dependent: :restrict_with_error

  # Валидации
  validates :name, presence: true, length: { maximum: 100 }
  validates :normalized_name, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :rating_score, inclusion: { in: 1..10 }

  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :premium, -> { where(is_premium: true) }
  scope :by_rating, ->(min_rating) { where('rating_score >= ?', min_rating) }
  scope :by_country, ->(country_id) { where(country_id: country_id) }

  # Callbacks
  before_save :normalize_name
  before_save :clean_aliases
  after_commit :increment_cache_version

  class << self
    # Поиск бренда по названию или алиасу
    def find_by_name_or_alias(name)
      return nil if name.blank?
      
      normalized = normalize_string(name)
      
      # Точное совпадение по нормализованному названию
      brand = find_by(normalized_name: normalized)
      return brand if brand
      
      # Поиск по алиасам
      where("? = ANY(aliases)", normalized).first ||
      where("? ILIKE ANY(aliases)", "%#{normalized}%").first
    end

    # Создание или поиск бренда с автоматической нормализацией
    def find_or_create_by_name(name)
      return nil if name.blank?
      
      brand = find_by_name_or_alias(name)
      return brand if brand
      
      # Создаем новый бренд с базовыми параметрами
      create!(
        name: name.titleize,
        normalized_name: normalize_string(name),
        rating_score: determine_default_rating(name),
        is_premium: determine_premium_status(name),
        aliases: [normalize_string(name)]
      )
    end

    # Получение топ брендов для рекомендаций
    def top_brands(limit: 10)
      active.order(rating_score: :desc, name: :asc).limit(limit)
    end

    private

    def normalize_string(str)
      str.to_s.strip.downcase.gsub(/[^\p{L}\p{N}\s]/, '').squeeze(' ')
    end

    def determine_default_rating(name)
      # Определяем базовый рейтинг на основе известных брендов
      premium_brands = ['michelin', 'мишлен', 'continental', 'континенталь', 'pirelli', 'пирелли', 'bridgestone', 'бриджстоун']
      good_brands = ['nokian', 'нокиан', 'hankook', 'ханкук', 'yokohama', 'йокохама', 'goodyear', 'гудиер']
      budget_brands = ['triangle', 'треугольник', 'linglong', 'линглонг', 'kama', 'кама']
      
      normalized = normalize_string(name)
      
      return 9 if premium_brands.any? { |brand| normalized.include?(brand) }
      return 7 if good_brands.any? { |brand| normalized.include?(brand) }
      return 3 if budget_brands.any? { |brand| normalized.include?(brand) }
      
      5 # Средний рейтинг по умолчанию
    end

    def determine_premium_status(name)
      premium_brands = ['michelin', 'мишлен', 'continental', 'континенталь', 'pirelli', 'пирелли', 
                       'bridgestone', 'бриджстоун', 'nokian', 'нокиан']
      
      normalized = normalize_string(name)
      premium_brands.any? { |brand| normalized.include?(brand) }
    end
  end

  # Расчет рейтинга для системы оценки шин
  def rating_for_evaluation
    base_rating = rating_score
    
    # Бонус за премиум статус
    base_rating += 1 if is_premium
    
    # Бонус за страну производства
    base_rating += (country&.rating_score || 5) * 0.1
    
    [base_rating, 10].min # Максимум 10 баллов
  end

  # Получение всех моделей бренда для определенного сезона
  def models_for_season(season = nil)
    return tire_models.active if season.blank?
    
    tire_models.active.where(season_type: season)
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