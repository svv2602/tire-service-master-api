class UserSocialAccount < ApplicationRecord
  belongs_to :user

  validates :provider, presence: true, inclusion: { in: %w[google facebook apple], message: "%{value} не поддерживается" }
  validates :provider_user_id, presence: true
  validates :provider_user_id, uniqueness: { scope: :provider, message: "уже существует для этого провайдера" }

  scope :by_provider, ->(provider) { where(provider: provider) }
  scope :google, -> { by_provider('google') }
  scope :facebook, -> { by_provider('facebook') }
  scope :apple, -> { by_provider('apple') }

  def self.find_by_provider_credentials(provider, provider_user_id)
    find_by(provider: provider, provider_user_id: provider_user_id)
  end
end
