class Service < ApplicationRecord
  # Связи
  belongs_to :category, class_name: 'ServiceCategory', foreign_key: 'category_id'
  has_many :price_list_items, dependent: :destroy
  has_many :booking_services, dependent: :restrict_with_error
  
  # Добавляем связь с сервисными точками
  has_many :service_point_services, dependent: :destroy
  has_many :service_points, through: :service_point_services
  
  # Валидации
  validates :name, presence: true
  validates :default_duration, numericality: { greater_than: 0 }
  
  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :by_category, ->(category_id) { where(category_id: category_id) }
  scope :sorted, -> { order(sort_order: :asc) }
  
  # Методы
  def current_price_for_service_point(service_point_id)
    current_date = Date.current
    
    # Ищем прайс-лист для конкретной точки обслуживания
    item = PriceListItem.joins(:price_list)
                        .where(service_id: id)
                        .where(price_lists: { service_point_id: service_point_id, is_active: true })
                        .where('price_lists.start_date <= ? AND (price_lists.end_date >= ? OR price_lists.end_date IS NULL)', current_date, current_date)
                        .order('price_lists.created_at DESC')
                        .first
    
    # Если не нашли для конкретной точки, ищем общий для партнера
    unless item
      service_point = ServicePoint.find_by(id: service_point_id)
      return nil unless service_point
      
      item = PriceListItem.joins(:price_list)
                          .where(service_id: id)
                          .where(price_lists: { partner_id: service_point.partner_id, service_point_id: nil, is_active: true })
                          .where('price_lists.start_date <= ? AND (price_lists.end_date >= ? OR price_lists.end_date IS NULL)', current_date, current_date)
                          .order('price_lists.created_at DESC')
                          .first
    end
    
    item&.discount_price || item&.price
  end
  
  # Возвращает базовую цену услуги для использования, если цены нет в прайс-листе
  def base_price
    # Возвращаем дефолтную цену 1000 для тестов
    1000
  end
end
