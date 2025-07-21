class EmailTemplateSerializer < ActiveModel::Serializer
  attributes :id, :name, :subject, :body, :template_type, :language, 
             :is_active, :variables_array, :description, :created_at, :updated_at,
             :template_type_name, :status_text, :all_variables, :custom_variables_by_category

  has_many :custom_variables, serializer: CustomVariableSerializer

  def variables_array
    object.variables_array
  end

  def template_type_name
    object.template_type_name
  end

  def status_text
    object.status_text
  end

  def all_variables
    object.all_variables
  end

  def custom_variables_by_category
    object.custom_variables_by_category.transform_values do |variables|
      ActiveModel::Serializer::CollectionSerializer.new(
        variables, 
        serializer: CustomVariableSerializer
      ).as_json
    end
  end
end 