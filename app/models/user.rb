class User < ApplicationRecord
  has_secure_password
  
  # Атрибуты
  attr_accessor :skip_role_specific_record
  
  # Связи
  belongs_to :role, class_name: 'UserRole', foreign_key: 'role_id', optional: true
  has_one :administrator, dependent: :destroy
  has_one :partner, dependent: :destroy
  has_one :client, dependent: :destroy
  has_one :manager, dependent: :destroy
  has_one :operator, dependent: :destroy
  has_many :authored_articles, class_name: 'Article', foreign_key: 'author_id', dependent: :destroy
  has_many :social_accounts, class_name: 'UserSocialAccount', dependent: :destroy
  has_many :system_logs, dependent: :nullify
  has_many :notifications, dependent: :destroy
  has_many :notification_settings, dependent: :destroy
  
  # Валидации
  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }, unless: -> { phone.present? }
  validates :phone, uniqueness: true, allow_blank: true
  validates :role_id, presence: true
  validates :first_name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :last_name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :password, length: { minimum: 6 }, if: -> { password.present? }
  
  # Кастомная валидация для телефона
  validate :phone_format_valid
  
  # Коллбэки
  before_validation :normalize_email, :normalize_phone
  after_create :create_role_specific_record, unless: :skip_role_specific_record
  
  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :with_role, ->(role_name) { joins(:role).where(user_roles: { name: role_name }) }
  scope :by_role, ->(role_name) { with_role(role_name) }
  scope :admins, -> { with_role('admin') }
  scope :partners, -> { with_role('partner') }
  scope :managers, -> { with_role('manager') }
  scope :clients, -> { with_role('client') }
  
  # Поиск
  scope :search, ->(query) do
    return all if query.blank?
    
    query_downcase = query.downcase
    where("LOWER(email) LIKE ? OR LOWER(first_name) LIKE ? OR LOWER(last_name) LIKE ?", 
          "%#{query_downcase}%", "%#{query_downcase}%", "%#{query_downcase}%")
  end
  
  # Методы ролей
  def admin?
    role&.name == 'admin'
  end
  
  def partner?
    role&.name == 'partner'
  end
  
  def manager?
    role&.name == 'manager'
  end
  
  def client?
    role&.name == 'client'
  end
  
  def operator?
    role&.name == 'operator'
  end
  
  # Методы пользователя
  def full_name
    if middle_name.present?
      "#{last_name} #{first_name} #{middle_name}"
    else
      "#{first_name} #{last_name}"
    end
  end
  
  def verify_email!
    update(email_verified: true)
  end
  
  def verify_phone!
    update(phone_verified: true)
  end
  
  def update_last_login!
    update_column(:last_login, Time.current)
  end
  
  def activate!
    update!(is_active: true)
  end
  
  def deactivate!
    update!(is_active: false)
  end
  
  def can_be_deleted_by?(current_user)
    return false unless current_user&.admin?
    return false if current_user.id == id
    true
  end
  
  private
  
  def normalize_email
    self.email = email.downcase if email.present?
  end
  
  def normalize_phone
    if phone.present?
      # Удаляем все символы кроме цифр и плюса
      normalized = phone.gsub(/[^\d+]/, '')
      # Если после нормализации остались только буквы или пустая строка, устанавливаем nil
      self.phone = normalized.empty? ? nil : normalized
    end
  end
  
  def phone_format_valid
    return if phone.blank?
    
    unless phone.match?(/\A\+?[0-9]{10,15}\z/)
      errors.add(:phone, 'is invalid')
    end
  end
  
  def create_role_specific_record
    return unless role
    
    case role.name
    when 'client'
      # Создаем запись клиента
      Client.create!(user: self) unless client
    when 'admin'
      # Создаем запись администратора
      Administrator.create!(user: self) unless administrator
    when 'partner'
      # Создаем запись партнера
      Partner.create!(user: self) unless partner
    when 'manager'
      # Создаем запись менеджера
      Manager.create!(user: self) unless manager
    when 'operator'
      # Создаем запись оператора
      Operator.create!(user: self) unless operator
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "Не удалось создать связанную запись для пользователя #{id}: #{e.message}"
  end
end
