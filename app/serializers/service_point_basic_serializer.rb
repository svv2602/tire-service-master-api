# Базовый сериализатор для точек обслуживания (без связанных данных)
class ServicePointBasicSerializer < ActiveModel::Serializer
  attributes :id, :name, :address, :contact_phone, :status
  
  def status
    {
      id: object.status.id,
      name: object.status.name
    }
  end
end 