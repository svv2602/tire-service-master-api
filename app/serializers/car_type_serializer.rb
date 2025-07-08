class CarTypeSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :is_active, :created_at, :updated_at,
             :localized_name, :localized_description
  
  def localized_name
    object.localized_name(current_locale)
  end
  
  def localized_description
    object.localized_description(current_locale)
  end
  
  private
  
  def current_locale
    # Получаем локаль из заголовков запроса или используем текущую локаль I18n
    @instance_options[:locale] || I18n.locale
  end
end
