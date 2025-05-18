class CarTypeSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :is_active, :created_at, :updated_at
end
