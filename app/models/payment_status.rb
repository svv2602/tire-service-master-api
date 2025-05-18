class PaymentStatus < ApplicationRecord
  # Связи
  has_many :bookings, foreign_key: 'payment_status_id', dependent: :restrict_with_error
  
  # Валидации
  validates :name, presence: true
  
  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :sorted, -> { order(sort_order: :asc) }
  
  # Предопределенные статусы с безопасной обработкой nil
  def self.pending_id
    status = find_by(name: 'pending')
    status&.id || create_with(description: 'Payment is expected', 
                            color: '#FFC107', 
                            sort_order: 1).find_or_create_by!(name: 'pending').id
  end
  
  def self.paid_id
    status = find_by(name: 'paid')
    status&.id || create_with(description: 'Payment has been successfully processed', 
                            color: '#4CAF50', 
                            sort_order: 2).find_or_create_by!(name: 'paid').id
  end
  
  def self.failed_id
    status = find_by(name: 'failed')
    status&.id || create_with(description: 'Payment attempt failed', 
                            color: '#F44336', 
                            sort_order: 3).find_or_create_by!(name: 'failed').id
  end
  
  def self.refunded_id
    status = find_by(name: 'refunded')
    status&.id || create_with(description: 'Payment has been refunded', 
                            color: '#2196F3', 
                            sort_order: 4).find_or_create_by!(name: 'refunded').id
  end
  
  def self.partially_refunded_id
    status = find_by(name: 'partially_refunded')
    status&.id || create_with(description: 'Payment has been partially refunded', 
                            color: '#9C27B0', 
                            sort_order: 5).find_or_create_by!(name: 'partially_refunded').id
  end
end
