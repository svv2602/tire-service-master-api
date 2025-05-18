class UserSocialAccount < ApplicationRecord
  # Связи
  belongs_to :user
  
  # Валидации
  validates :provider, presence: true
  validates :provider_user_id, presence: true
  validates :provider, uniqueness: { scope: :provider_user_id }
  
  # Поддерживаемые провайдеры
  PROVIDERS = ['google', 'apple', 'facebook'].freeze
  
  validates :provider, inclusion: { in: PROVIDERS }
end
