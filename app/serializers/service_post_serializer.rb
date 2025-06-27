# Сериализатор для постов обслуживания
class ServicePostSerializer < ActiveModel::Serializer
  attributes :id, :post_number, :name, :slot_duration, :is_active, :description, 
             :created_at, :updated_at, :display_name, :slot_duration_in_seconds,
             :has_custom_schedule, :working_days, :custom_hours, :working_days_list,
             :category_name, :service_category_id
  
  belongs_to :service_point, serializer: ServicePointBasicSerializer
  belongs_to :service_category, serializer: ServiceCategorySerializer
  
  # Дополнительные атрибуты для удобства
  def display_name
    object.display_name
  end
  
  def slot_duration_in_seconds
    object.slot_duration_in_seconds
  end
  
  def category_name
    object.category_name
  end
  
  # Возвращает список рабочих дней для удобства фронтенда
  def working_days_list
    return [] unless object.has_custom_schedule?
    object.working_days_list
  end
  
  # Возвращает working_days только если у поста есть индивидуальное расписание
  def working_days
    return nil unless object.has_custom_schedule?
    object.working_days
  end
  
  # Возвращает custom_hours только если у поста есть индивидуальное расписание
  def custom_hours
    return nil unless object.has_custom_schedule?
    object.custom_hours
  end
end 