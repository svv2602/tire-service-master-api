class ServiceCategorySerializer < ActiveModel::Serializer
  attributes :id, :name, :name_uk, :description, :description_uk, :sort_order, :is_active, 
             :created_at, :updated_at, :services_count, :localized_name, :localized_description

  def services_count
    object.services_count
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
