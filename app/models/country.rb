# frozen_string_literal: true

# Модель справочника стран производства шин
class Country < ApplicationRecord
  # Ассоциации
  has_many :tire_brands, dependent: :restrict_with_error
  has_many :supplier_tire_products, dependent: :restrict_with_error

  # Валидации
  validates :name, presence: true, length: { maximum: 100 }
  validates :iso_code, length: { maximum: 3 }, allow_blank: true
  validates :rating_score, inclusion: { in: 1..10 }
  # aliases не требует отдельной валидации, так как это массив

  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :by_rating, ->(min_rating) { where('rating_score >= ?', min_rating) }
  scope :premium_countries, -> { where('rating_score >= 8') }

  # Callbacks
  before_save :normalize_name
  before_save :clean_aliases

  class << self
    # Поиск страны по названию или алиасу
    def find_by_name_or_alias(name)
      return nil if name.blank?
      
      normalized = normalize_string(name)
      
      # Точное совпадение по нормализованному названию
      country = find_by(normalized_name: normalized)
      return country if country
      
      # Поиск по алиасам
      where("? = ANY(aliases)", normalized).first ||
      where("? ILIKE ANY(aliases)", "%#{normalized}%").first
    end

    # Создание или поиск страны с автоматической нормализацией
    def find_or_create_by_name(name)
      return nil if name.blank?
      
      country = find_by_name_or_alias(name)
      return country if country
      
      # Создаем новую страну с базовыми параметрами
      create!(
        name: name.titleize,
        normalized_name: normalize_string(name),
        rating_score: determine_default_rating(name),
        aliases: [normalize_string(name)]
      )
    end

    private

    def normalize_string(str)
      str.to_s.strip.downcase.gsub(/[^\p{L}\p{N}\s]/, '').squeeze(' ')
    end

    def determine_default_rating(name)
      # Определяем базовый рейтинг на основе известных стран
      premium_countries = ['германия', 'germany', 'япония', 'japan', 'южная корея', 'south korea']
      good_countries = ['франция', 'france', 'италия', 'italy', 'турция', 'turkey']
      
      normalized = normalize_string(name)
      
      return 9 if premium_countries.any? { |country| normalized.include?(country) }
      return 7 if good_countries.any? { |country| normalized.include?(country) }
      
      5 # Средний рейтинг по умолчанию
    end
  end

  # Расчет рейтинга для системы оценки шин
  def rating_for_evaluation
    rating_score
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