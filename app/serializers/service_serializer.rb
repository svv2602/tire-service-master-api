class ServiceSerializer < ActiveModel::Serializer
  attributes :id, :category_id, :name, :description, :default_duration, 
             :sort_order, :is_active, :created_at, :updated_at
  
  belongs_to :category, serializer: ServiceCategorySerializer

  def category
    object.category || ServiceCategory.find(object.category_id)
  end
end
