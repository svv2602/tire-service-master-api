class RegionSerializer < ActiveModel::Serializer
  attributes :id, :name, :name_ru, :name_uk, :code, :is_active, :cities_count
  
  def cities_count
    object.cities.count
  end
  
  # Добавляем локализованное название в зависимости от контекста
  def localized_name
    locale = instance_options[:locale] || 'ru'
    object.localized_name(locale)
  end
end 