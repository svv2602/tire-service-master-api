class PartnerApplication < ApplicationRecord
  # Enum для статусов заявки
  enum :status, {
    pending: 'new',                # Новая заявка
    in_progress: 'in_progress',    # В работе
    approved: 'approved',          # Одобрена
    rejected: 'rejected',          # Отклонена
    connected: 'connected'         # Подключен как партнер
  }

  # Связи
  belongs_to :region, optional: true
  belongs_to :city_record, class_name: 'City', foreign_key: 'city_record_id', optional: true
  belongs_to :processed_by, class_name: 'User', optional: true

  # Валидации
  validates :company_name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :business_description, presence: true, length: { minimum: 10, maximum: 1000 }
  validates :contact_person, presence: true, length: { minimum: 2, maximum: 100 }
  validates :email, presence: true, 
                   format: { with: URI::MailTo::EMAIL_REGEXP },
                   uniqueness: { case_sensitive: false }
  validates :phone, presence: true, 
                   format: { with: /\A\+?[1-9]\d{1,14}\z/ }
  validates :city, presence: true, length: { minimum: 2, maximum: 50 }
  validates :expected_service_points, presence: true, 
                                     numericality: { only_integer: true, greater_than: 0, less_than: 100 }
  validates :status, presence: true

  # Скоупы
  scope :by_status, ->(status) { where(status: status) }
  scope :recent, -> { order(created_at: :desc) }
  scope :processed, -> { where.not(processed_at: nil) }
  scope :unprocessed, -> { where(processed_at: nil) }
  scope :by_region, ->(region_id) { where(region_id: region_id) }
  scope :search_by_company, ->(query) { where("company_name ILIKE ?", "%#{query}%") }
  scope :search_by_contact, ->(query) { where("contact_person ILIKE ?", "%#{query}%") }

  # Колбеки
  before_validation :normalize_email
  before_validation :normalize_phone
  after_update :set_processed_at, if: :saved_change_to_status?

  # Методы
  def can_be_processed_by?(user)
    user&.admin? || user&.manager?
  end

  def full_address
    [city, address].compact.join(', ')
  end

  def processed?
    processed_at.present?
  end

  def processing_duration
    return nil unless processed?
    processed_at - created_at
  end

  def region_name
    region&.name || 'Не указан'
  end

  def city_name
    city_record&.name || city
  end

  def status_color
    case status
    when 'new' then 'info'
    when 'in_progress' then 'warning'
    when 'approved' then 'success'
    when 'rejected' then 'error'
    when 'connected' then 'success'
    else 'default'
    end
  end

  def status_label
    case status
    when 'new' then 'Новая'
    when 'in_progress' then 'В работе'
    when 'approved' then 'Одобрена'
    when 'rejected' then 'Отклонена'
    when 'connected' then 'Подключен'
    else status.humanize
    end
  end

  # Методы для изменения статуса
  def mark_as_in_progress!(user)
    update!(status: 'in_progress', processed_by: user)
  end

  def approve!(user, notes = nil)
    update!(status: 'approved', processed_by: user, admin_notes: notes)
  end

  def reject!(user, notes = nil)
    update!(status: 'rejected', processed_by: user, admin_notes: notes)
  end

  def mark_as_connected!(user, notes = nil)
    update!(status: 'connected', processed_by: user, admin_notes: notes)
  end

  private

  def normalize_email
    self.email = email&.downcase&.strip
  end

  def normalize_phone
    # Убираем все символы кроме цифр и плюса
    self.phone = phone&.gsub(/[^\d+]/, '')
  end

  def set_processed_at
    self.processed_at = Time.current if status_changed? && status != 'new'
  end
end 