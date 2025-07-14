class ServiceSerializer < ActiveModel::Serializer
  attributes :id, :category_id, :name, :name_uk, :description, :description_uk,
             :sort_order, :is_active, :created_at, :updated_at, :localized_name, :localized_description
  
  belongs_to :category, serializer: ServiceCategorySerializer

  def category
    object.category || ServiceCategory.find(object.category_id)
  end
  
  def localized_name
    locale = instance_options[:locale] || 'ru'
    object.localized_name(locale)
  end
  
  def localized_description
    locale = instance_options[:locale] || 'ru'
    object.localized_description(locale)
  end
end
