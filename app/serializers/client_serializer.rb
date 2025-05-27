class ClientSerializer < ActiveModel::Serializer
  attributes :id, :user_id, :preferred_notification_method, :marketing_consent, 
             :created_at, :updated_at, :first_name, :last_name, :middle_name, 
             :phone, :email, :is_active

  belongs_to :user, serializer: UserSerializer

  # Делегируем поля пользователя для удобства
  def first_name
    object.user&.first_name
  end

  def last_name
    object.user&.last_name
  end

  def middle_name
    object.user&.middle_name
  end

  def phone
    object.user&.phone
  end

  def email
    object.user&.email
  end

  def is_active
    object.user&.is_active || false
  end
end 