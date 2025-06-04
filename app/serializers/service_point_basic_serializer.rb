# Базовый сериализатор для точек обслуживания (без связанных данных)
class ServicePointBasicSerializer < ActiveModel::Serializer
  attributes :id, :name, :address, :contact_phone, :work_status, :is_active
end 