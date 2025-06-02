class Partner < ApplicationRecord
  # Связи
  belongs_to :user
  belongs_to :region, optional: true
  belongs_to :city, optional: true
  has_many :managers, dependent: :destroy
  has_many :service_points, dependent: :destroy
  has_many :price_lists, dependent: :destroy
  has_many :promotions, dependent: :destroy
  
  # Валидации
  validates :user_id, presence: true, uniqueness: true
  validates :company_name, presence: true
  validates :contact_person, presence: true
  validates :tax_number, uniqueness: true, allow_blank: true
  validates :legal_address, presence: true
  
  # Скоупы
  scope :with_active_user, -> { joins(:user).where(users: { is_active: true }) }
  scope :active, -> { where(is_active: true) }
  
  # Методы
  def total_clients_served
    service_points.sum(:total_clients_served)
  end
  
  def average_rating
    service_points_count = service_points.count
    return 0 if service_points_count.zero?
    
    service_points.sum(:average_rating) / service_points_count
  end
  
  def name
    company_name
  end
  
  # Метод для переключения активности партнера
  # Возвращает true при успешном выполнении, false при ошибке
  def toggle_active(activate = nil, change_user_roles = true)
    # Если активация не указана явно, инвертируем текущее значение
    new_status = activate.nil? ? !is_active : activate
    
    # Задаем соответствующий статус для сервисных точек
    new_service_point_status_id = new_status ? 
      ServicePointStatus.active_id : 
      ServicePointStatus.temporarily_closed_id
    
    # Получаем роль клиента для изменения ролей пользователей
    client_role = UserRole.find_by(name: 'client')
    partner_role = UserRole.find_by(name: 'partner')
    manager_role = UserRole.find_by(name: 'manager')
    
    # Начинаем транзакцию для обеспечения целостности данных
    ActiveRecord::Base.transaction do
      # 1. Обновляем поле is_active партнера
      update!(is_active: new_status)
      
      # 2. Обновляем статус всех сервисных точек партнера
      service_points.update_all(status_id: new_service_point_status_id)
      
      # 3. Если активируем или необходимо изменить роли пользователей
      if change_user_roles && user.present?
        if !new_status
          # При деактивации меняем роль пользователя партнера на "client"
          user.update!(role_id: client_role.id) if client_role.present?
          
          # Меняем роли всех менеджеров партнера на "client"
          managers.includes(:user).each do |manager|
            next unless manager.present? && manager.user.present?
            # Создаем клиента для этого пользователя, если его еще нет
            unless Client.exists?(user_id: manager.user.id)
              Client.create!(
                user_id: manager.user.id,
                preferred_notification_method: 'email'
              )
            end
            manager.user.update!(role_id: client_role.id) if client_role.present?
          end
        else
          # При активации восстанавливаем роль партнера у владельца
          user.update!(role_id: partner_role.id) if partner_role.present?
          
          # Роли менеджеров не восстанавливаем автоматически, это должно быть сделано вручную
        end
      end
    end
    
    true # Возвращаем true при успешном выполнении
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Ошибка при изменении активности партнера: #{e.message}")
    false # Возвращаем false при ошибке
  rescue StandardError => e
    Rails.logger.error("Непредвиденная ошибка при изменении активности партнера: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    false # Возвращаем false при любой другой ошибке
  end
end
