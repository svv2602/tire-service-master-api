class EmailTemplateSerializer < ActiveModel::Serializer
  attributes :id, :name, :subject, :body, :template_type, :language, 
             :is_active, :variables_array, :description, :created_at, :updated_at,
             :template_type_name, :status_text

  def variables_array
    object.variables_array
  end

  def template_type_name
    object.template_type_name
  end

  def status_text
    object.status_text
  end
end 