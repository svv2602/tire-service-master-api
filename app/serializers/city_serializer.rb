class CitySerializer < ActiveModel::Serializer
  attributes :id, :name, :name_ru, :name_uk, :region_id, :is_active
  
  belongs_to :region
  
  # Добавляем локализованное название в зависимости от контекста
  def localized_name
    locale = instance_options[:locale] || 'ru'
    object.localized_name(locale)
  end
  
  # Полное название с регионом
  def full_localized_name
    locale = instance_options[:locale] || 'ru'
    object.full_name(locale)
  end
end 