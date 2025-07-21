class CustomVariableSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :example_value, :category, :is_active,
             :created_at, :updated_at, :variable_placeholder, :category_name

  belongs_to :created_by, serializer: UserSerializer

  def variable_placeholder
    object.variable_placeholder
  end

  def category_name
    object.category_name
  end
end 