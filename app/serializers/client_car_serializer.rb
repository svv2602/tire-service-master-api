class ClientCarSerializer < ActiveModel::Serializer
  attributes :id, :year, :is_primary, :created_at, :updated_at
  
  belongs_to :brand, class_name: 'CarBrand', foreign_key: 'car_brand_id'
  belongs_to :model, class_name: 'CarModel', foreign_key: 'car_model_id'
  belongs_to :car_type, optional: true
  
  def brand
    {
      id: object.brand.id,
      name: object.brand.name
    }
  end
  
  def model
    {
      id: object.model.id,
      name: object.model.name
    }
  end
  
  def car_type
    if object.car_type
      {
        id: object.car_type.id,
        name: object.car_type.name,
        description: object.car_type.description
      }
    else
      nil
    end
  end
end
