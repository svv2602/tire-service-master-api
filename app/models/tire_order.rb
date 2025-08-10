class TireOrder < ApplicationRecord
  # Константы для статусов
  STATUSES = {
    'draft' => 'Корзина',
    'submitted' => 'Отправлен',
    'confirmed' => 'Подтвержден',
    'processing' => 'В обработке',
    'completed' => 'Выполнен',
    'cancelled' => 'Отменен',
    'archived' => 'Архивирован'
  }.freeze

  # Связи
  belongs_to :user
  belongs_to :supplier
  has_many :tire_order_items, dependent: :destroy
  has_many :supplier_tire_products, through: :tire_order_items
  
  # Система вознаграждений
  has_many :partner_rewards, dependent: :destroy

  # Валидации
  validates :status, presence: true, inclusion: { in: STATUSES.keys }
  validates :client_name, presence: true, length: { maximum: 255 }
  validates :client_phone, presence: true, 
            format: { 
              with: /\A\+?[\d\s\-\(\)]{10,20}\z/, 
              message: 'должен быть в правильном формате' 
            }
  validates :total_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Скоупы
  scope :by_status, ->(status) { where(status: status) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_supplier, ->(supplier_id) { where(supplier_id: supplier_id) }
  scope :draft, -> { where(status: 'draft') }
  scope :submitted, -> { where(status: 'submitted') }
  scope :active, -> { where.not(status: ['cancelled', 'archived']) }
  scope :recent, -> { order(updated_at: :desc) }

  # Коллбэки
  before_save :calculate_total_amount
  after_update :clear_empty_draft_orders
  after_update :calculate_partner_reward, if: :should_calculate_reward?

  # Методы экземпляра
  def status_display
    STATUSES[status] || status
  end

  def draft?
    status == 'draft'
  end

  def submitted?
    status == 'submitted'
  end

  def can_be_edited?
    draft?
  end

  def can_be_cancelled_by_user?
    %w[draft submitted confirmed processing].include?(status)
  end

  def can_be_cancelled_by_admin?
    !%w[completed archived].include?(status)
  end

  def can_be_archived?
    !draft?
  end

  def items_count
    tire_order_items.sum(:quantity)
  end

  def formatted_total
    return 'Не указана' unless total_amount
    "#{total_amount.to_f} UAH"
  end

  # Переходы статусов
  def submit!
    return false unless draft?
    
    if tire_order_items.empty?
      errors.add(:base, 'Нельзя отправить пустой заказ')
      return false
    end

    update!(status: 'submitted')
  end

  def confirm!
    return false unless submitted?
    update!(status: 'confirmed')
  end

  def start_processing!
    return false unless status == 'confirmed'
    update!(status: 'processing')
  end

  def complete!
    return false unless status == 'processing'
    update!(status: 'completed')
  end

  def cancel!
    return false if %w[completed archived].include?(status)
    update!(status: 'cancelled')
  end

  def archive!
    return false if draft?
    update!(status: 'archived')
  end

  private

  def calculate_total_amount
    self.total_amount = tire_order_items.sum { |item| item.quantity * item.price_at_order }
  end

  def clear_empty_draft_orders
    # Удаляем пустые корзины через 30 дней
    if draft? && tire_order_items.empty? && updated_at < 30.days.ago
      destroy
    end
  end
  
  # Определяет, нужно ли рассчитывать вознаграждение
  def should_calculate_reward?
    status_changed? && %w[submitted confirmed completed].include?(status)
  end
  
  # Рассчитывает вознаграждение партнера
  def calculate_partner_reward
    # Проверяем, что пользователь либо партнер, либо оператор партнера
    return unless user&.partner? || user&.operator?
    
    service = RewardCalculationService.new(self)
    
    if service.reward_exists?
      service.recalculate_existing_reward
    else
      service.calculate_and_create_reward
    end
  rescue => e
    Rails.logger.error "Ошибка расчета вознаграждения для TireOrder ##{id}: #{e.message}"
  end
end