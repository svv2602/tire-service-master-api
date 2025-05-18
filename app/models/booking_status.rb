class BookingStatus < ApplicationRecord
  # Связи
  has_many :bookings, foreign_key: 'status_id', dependent: :restrict_with_error
  
  # Валидации
  validates :name, presence: true, uniqueness: true
  
  # Скоупы
  scope :active, -> { where(is_active: true) }
  scope :sorted, -> { order(sort_order: :asc) }
  
  # Предопределенные статусы с безопасной обработкой nil
  def self.pending_id
    status = find_by(name: 'pending')
    status&.id || create_with(description: 'Booking has been created but not confirmed', 
                              color: '#FFC107', 
                              sort_order: 1).find_or_create_by!(name: 'pending').id
  end
  
  def self.confirmed_id
    status = find_by(name: 'confirmed')
    status&.id || create_with(description: 'Booking has been confirmed by the service point', 
                              color: '#4CAF50', 
                              sort_order: 2).find_or_create_by!(name: 'confirmed').id
  end
  
  def self.in_progress_id
    status = find_by(name: 'in_progress')
    status&.id || create_with(description: 'Service is currently being provided', 
                              color: '#2196F3', 
                              sort_order: 3).find_or_create_by!(name: 'in_progress').id
  end
  
  def self.completed_id
    status = find_by(name: 'completed')
    status&.id || create_with(description: 'Service has been successfully completed', 
                              color: '#8BC34A', 
                              sort_order: 4).find_or_create_by!(name: 'completed').id
  end
  
  def self.canceled_by_client_id
    status = find_by(name: 'canceled_by_client')
    status&.id || create_with(description: 'Booking was canceled by the client', 
                              color: '#F44336', 
                              sort_order: 5).find_or_create_by!(name: 'canceled_by_client').id
  end
  
  def self.canceled_by_partner_id
    status = find_by(name: 'canceled_by_partner')
    status&.id || create_with(description: 'Booking was canceled by the partner', 
                              color: '#FF5722', 
                              sort_order: 6).find_or_create_by!(name: 'canceled_by_partner').id
  end
  
  def self.no_show_id
    status = find_by(name: 'no_show')
    status&.id || create_with(description: 'Client did not show up', 
                              color: '#9C27B0', 
                              sort_order: 7).find_or_create_by!(name: 'no_show').id
  end
  
  # Группы статусов
  def self.active_statuses
    where(name: ['pending', 'confirmed', 'in_progress']).pluck(:id)
  end
  
  def self.completed_statuses
    where(name: ['completed']).pluck(:id)
  end
  
  def self.canceled_statuses
    where(name: ['canceled_by_client', 'canceled_by_partner', 'no_show']).pluck(:id)
  end
end
