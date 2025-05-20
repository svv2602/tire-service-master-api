class User < ApplicationRecord
  has_secure_password
  
  # Связи
  belongs_to :role, class_name: 'UserRole', foreign_key: 'role_id'
  has_one :administrator, dependent: :destroy
  has_one :partner, dependent: :destroy
  has_one :client, dependent: :destroy
  has_one :manager, dependent: :destroy
  has_many :social_accounts, class_name: 'UserSocialAccount', dependent: :destroy
  has_many :system_logs, dependent: :nullify
  
  # Валидации
  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, uniqueness: true, format: { with: /\A\+?[0-9]{10,15}\z/ }, allow_nil: true
  validates :role_id, presence: true
  
  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :with_role, ->(role_name) { joins(:role).where(user_roles: { name: role_name }) }
  scope :admins, -> { with_role('admin') }
  scope :partners, -> { with_role('partner') }
  scope :managers, -> { with_role('manager') }
  scope :clients, -> { with_role('client') }
  
  # Методы
  def admin?
    role.name == 'admin'
  end
  
  def partner?
    role.name == 'partner'
  end
  
  def manager?
    role.name == 'manager'
  end
  
  def client?
    role.name == 'client'
  end
  
  def full_name
    [first_name, last_name].compact.join(' ')
  end
  
  def verify_email!
    update(email_verified: true)
  end
  
  def verify_phone!
    update(phone_verified: true)
  end
  
  def update_last_login!
    update(last_login: Time.current)
  end
end
