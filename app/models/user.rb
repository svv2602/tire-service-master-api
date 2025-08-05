class User < ApplicationRecord
  include Auditable
  
  has_secure_password
  
  # Атрибуты
  attr_accessor :skip_role_specific_record
  
  # Константы
  SUPPORTED_LOCALES = %w[uk ru].freeze
  DEFAULT_LOCALE = 'uk'.freeze
  
  # Связи
  belongs_to :role, class_name: 'UserRole', foreign_key: 'role_id', required: true
  has_one :administrator, dependent: :destroy
  has_one :partner, dependent: :destroy
  has_one :client, dependent: :destroy
  has_one :manager, dependent: :destroy
  has_one :operator, dependent: :destroy
  has_many :authored_articles, class_name: 'Article', foreign_key: 'author_id', dependent: :destroy
  has_many :social_accounts, class_name: 'UserSocialAccount', dependent: :destroy
  has_many :system_logs, dependent: :nullify
  has_many :notifications, as: :recipient, dependent: :destroy
  # has_many :notification_settings, dependent: :destroy # Временно закомментировано - таблица не существует
  
  # Telegram интеграция
  has_one :telegram_subscription, dependent: :destroy
  has_many :telegram_notifications, dependent: :destroy
  
  # Заказы шин
  has_many :tire_orders, dependent: :destroy
  
  # Push уведомления
  has_many :push_subscriptions, dependent: :destroy
  
  # Валидации
  validates :email, uniqueness: { case_sensitive: false, allow_blank: true }, format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :phone, uniqueness: { case_sensitive: false, allow_blank: true }, format: { with: /\A\+?[0-9]{10,15}\z/, allow_blank: true }
  validates :role_id, presence: true
  validates :first_name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :last_name, length: { minimum: 2, maximum: 50, allow_blank: true }
  validates :password, length: { minimum: 6 }, if: -> { password.present? }
  validates :preferred_locale, inclusion: { in: SUPPORTED_LOCALES }
  
  # ✅ НОВАЯ ВАЛИДАЦИЯ: email ИЛИ телефон обязателен
  validate :email_or_phone_present
  
  # Кастомная валидация для телефона
  validate :phone_format_valid
  
  # Коллбэки
  before_validation :normalize_email, :normalize_phone, :set_default_locale
  after_create :create_role_specific_record, unless: :skip_role_specific_record
  
  # Callback'ы для инвалидации кэша
  after_save :invalidate_users_cache
  after_destroy :invalidate_users_cache
  
  # Связи для блокировки
  belongs_to :suspended_by, class_name: 'User', optional: true
  has_many :suspended_users, class_name: 'User', foreign_key: 'suspended_by_id', dependent: :nullify

  # Скоупы
  scope :active, -> { where(is_active: true, is_suspended: false) }
  scope :inactive, -> { where(is_active: false) }
  scope :suspended, -> { where(is_suspended: true) }
  scope :not_suspended, -> { where(is_suspended: false) }
  scope :suspension_expired, -> { where('suspended_until IS NOT NULL AND suspended_until < ?', Time.current) }
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
  
  # ✅ УЛУЧШЕННЫЙ МЕТОД: гибкий поиск по логину (email или телефон)
  def self.find_by_login(login)
    return nil if login.blank?
    
    if login.include?('@')
      # Поиск по email
      return find_by(email: login.downcase)
    else
      # Пробуем найти по разным форматам номера телефона
      normalized_login = login.gsub(/[^\d+]/, '')
      
      # Формат 1: как есть (например, "+380501234567")
      user = find_by(phone: normalized_login)
      return user if user
      
      # Формат 2: добавляем +38 к номеру без кода страны (например, "0501234567" -> "+380501234567")
      if normalized_login.match(/^\d{10}$/) && normalized_login.start_with?('0')
        user = find_by(phone: "+38#{normalized_login}")
        return user if user
      end
      
      # Формат 3: убираем код страны (например, "+380501234567" -> "0501234567")
      if normalized_login.match(/^\+?38\d{10}$/)
        clean_number = normalized_login.gsub(/^\+?38/, '0')
        user = find_by(phone: "+38#{clean_number}")
        return user if user
      end
      
      # Формат 4: для случаев когда номер сохранен без +
      if normalized_login.match(/^38\d{10}$/)
        user = find_by(phone: "+#{normalized_login}")
        return user if user
      end
      
      nil
    end
  end
  
  # Методы ролей
  def admin?
    role&.name == 'admin'
  end
  
  def super_admin?
    admin? && administrator&.access_level.to_i >= 10
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
  
  # Методы для работы с локалью
  def set_locale(locale)
    return false unless SUPPORTED_LOCALES.include?(locale.to_s)
    update(preferred_locale: locale)
  end
  
  private
  
  def normalize_email
    if email.present?
      self.email = email.downcase
    elsif email == ''
      # Конвертируем пустые строки в nil для корректной работы uniqueness валидации
      self.email = nil
    end
  end
  
  def normalize_phone
    if phone.present?
      # Удаляем все символы кроме цифр и плюса
      normalized = phone.gsub(/[^\d+]/, '')
      # Если после нормализации остались только буквы или пустая строка, устанавливаем nil
      self.phone = normalized.empty? ? nil : normalized
    elsif phone == ''
      # Конвертируем пустые строки в nil для корректной работы uniqueness валидации
      self.phone = nil
    end
  end
  
  def phone_format_valid
    return if phone.blank?
    
    unless phone.match?(/\A\+?[0-9]{10,15}\z/)
      errors.add(:phone, 'is invalid')
    end
  end
  
  # ✅ НОВАЯ ВАЛИДАЦИЯ: email ИЛИ телефон обязателен
  def email_or_phone_present
    if email.blank? && phone.blank?
      errors.add(:base, 'Необходимо указать email или номер телефона')
    end
  end
  
  def set_default_locale
    self.preferred_locale ||= DEFAULT_LOCALE
  end
  
  def create_role_specific_record
    return unless role
    
    case role.name
    when 'client'
      # Создаем запись клиента
      Client.create!(user: self) unless client
    when 'admin'
      # Создаем запись администратора
      Administrator.create!(user: self, position: 'Администратор', access_level: 10) unless administrator
    when 'partner'
      # Создаем запись партнера с обязательными полями
      region = Region.first
      city = region&.cities&.first
      Partner.create!(
        user: self,
        company_name: 'Компания не указана',
        contact_person: full_name,
        legal_address: 'Адрес не указан',
        region_id: region&.id,
        city_id: city&.id,
        is_active: true
      ) unless partner
    when 'manager'
      # Создаем запись менеджера сайта (без partner_id)
      Manager.create!(
        user: self,
        position: 'Менеджер сайта',
        access_level: 2,
        partner_id: nil
      ) unless manager
    # Операторы создаются только через OperatorsController с привязкой к партнеру
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "Не удалось создать связанную запись для пользователя #{id}: #{e.message}"
  end

  public

  # Методы для блокировки пользователей
  def suspend!(reason: nil, until_date: nil, suspended_by_user: nil)
    transaction do
      update!(
        is_suspended: true,
        suspension_reason: reason,
        suspended_until: until_date,
        suspended_by: suspended_by_user,
        suspended_at: Time.current
      )
      
      # Логируем блокировку
      Rails.logger.info "Пользователь #{email} заблокирован. Причина: #{reason}"
    end
  end

  def unsuspend!(unsuspended_by_user: nil)
    transaction do
      update!(
        is_suspended: false,
        suspension_reason: nil,
        suspended_until: nil,
        suspended_by: nil,
        suspended_at: nil
      )
      
      # Логируем разблокировку
      Rails.logger.info "Пользователь #{email} разблокирован пользователем #{unsuspended_by_user&.email}"
    end
  end

  def suspended?
    return false unless is_suspended?
    
    # Если указана дата окончания блокировки, проверяем её
    if suspended_until.present?
      return suspended_until > Time.current
    end
    
    # Если дата не указана - блокировка бессрочная
    true
  end

  def suspension_expired?
    return false unless is_suspended?
    return false if suspended_until.blank?
    
    suspended_until <= Time.current
  end

  def auto_unsuspend_if_expired!
    return false unless suspension_expired?
    
    unsuspend!
    true
  end

  def suspension_info
    return nil unless suspended?
    
    {
      is_suspended: is_suspended?,
      reason: suspension_reason,
      suspended_at: suspended_at,
      suspended_until: suspended_until,
      suspended_by: suspended_by&.full_name,
      is_permanent: suspended_until.blank?
    }
  end

  private

  # Инвалидация кэша пользователей при изменении данных
  def invalidate_users_cache
    # Очищаем все кэши связанные с пользователями
    Rails.cache.delete_matched("users/*")
    
    # Уведомляем о необходимости инвалидации кэша ролей
    ActiveSupport::Notifications.instrument('user_role_changed', {
      user_id: id,
      role: role&.name,
      changes: previous_changes
    })
    
    Rails.logger.info "🗑️ Users cache invalidated for user #{id}"
  end
end
