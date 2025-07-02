class ClientCarSerializer < ActiveModel::Serializer
  attributes :id, :brand_id, :model_id, :car_type_id, :year, :license_plate, :is_primary, :created_at, :updated_at, :brand, :model, :car_type
  
  def brand
    if object.brand
      {
        id: object.brand.id,
        name: object.brand.name
      }
    end
  end
  
  def model
    if object.model
      {
        id: object.model.id,
        name: object.model.name
      }
    end
  end
  
  def car_type
    if object.car_type
      {
        id: object.car_type.id,
        name: object.car_type.name,
        description: object.car_type.description
      }
    end
  end
end
