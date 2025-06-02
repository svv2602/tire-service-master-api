# Сериализатор для постов обслуживания
class ServicePostSerializer < ActiveModel::Serializer
  attributes :id, :post_number, :name, :slot_duration, :is_active, :description, 
             :created_at, :updated_at, :display_name, :slot_duration_in_seconds
  
  belongs_to :service_point, serializer: ServicePointBasicSerializer
  
  # Дополнительные атрибуты для удобства
  def display_name
    object.display_name
  end
  
  def slot_duration_in_seconds
    object.slot_duration_in_seconds
  end
end 