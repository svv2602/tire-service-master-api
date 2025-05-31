class ServiceCategorySerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :sort_order, :is_active, 
             :created_at, :updated_at, :services_count

  def services_count
    object.services_count
  end
end
