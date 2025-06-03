class RefactorServicePointStatusSystem < ActiveRecord::Migration[8.0]
  def up
    # Добавляем булево поле для активности (по умолчанию true - активна)
    add_column :service_points, :is_active, :boolean, default: true, null: false
    
    # Добавляем enum поле для рабочего состояния
    add_column :service_points, :work_status, :string, default: 'working', null: false
    
    # Создаем индекс для быстрого поиска активных точек
    add_index :service_points, :is_active
    add_index :service_points, :work_status
    add_index :service_points, [:is_active, :work_status]
    
    # Мигрируем данные из старой системы статусов
    ServicePoint.reset_column_information
    
    ServicePoint.find_each do |service_point|
      status_name = ServicePointStatus.find(service_point.status_id).name
      case status_name
      when 'active'
        service_point.update_columns(
          is_active: true,
          work_status: 'working'
        )
      when 'temporarily_closed'
        service_point.update_columns(
          is_active: true,  # точка активна, но временно не работает
          work_status: 'temporarily_closed'
        )
      when 'maintenance'
        service_point.update_columns(
          is_active: true,  # точка активна, но на обслуживании
          work_status: 'maintenance'
        )
      when 'closed'
        service_point.update_columns(
          is_active: false, # точка полностью неактивна
          work_status: 'suspended'
        )
      end
    end
    
    puts "Мигрировано #{ServicePoint.count} сервисных точек"
    
    # Убираем старое поле status_id (оставляем таблицу статусов для истории)
    remove_foreign_key :service_points, :service_point_statuses if foreign_key_exists?(:service_points, :service_point_statuses)
    remove_index :service_points, :status_id if index_exists?(:service_points, :status_id)
    remove_column :service_points, :status_id
  end
  
  def down
    # Восстанавливаем старую структуру
    add_reference :service_points, :status, null: false, foreign_key: { to_table: :service_point_statuses }, default: 1
    
    # Мигрируем данные обратно
    ServicePoint.reset_column_information
    
    ServicePoint.find_each do |service_point|
      if !service_point.is_active
        # Неактивные точки -> 'closed'
        service_point.update_column(:status_id, ServicePointStatus.find_by(name: 'closed')&.id || 3)
      else
        case service_point.work_status
        when 'working'
          service_point.update_column(:status_id, ServicePointStatus.find_by(name: 'active')&.id || 1)
        when 'temporarily_closed'
          service_point.update_column(:status_id, ServicePointStatus.find_by(name: 'temporarily_closed')&.id || 2)
        when 'maintenance'
          service_point.update_column(:status_id, ServicePointStatus.find_by(name: 'maintenance')&.id || 4)
        when 'suspended'
          service_point.update_column(:status_id, ServicePointStatus.find_by(name: 'closed')&.id || 3)
        end
      end
    end
    
    # Убираем новые поля
    remove_index :service_points, [:is_active, :work_status] if index_exists?(:service_points, [:is_active, :work_status])
    remove_index :service_points, :work_status if index_exists?(:service_points, :work_status)
    remove_index :service_points, :is_active if index_exists?(:service_points, :is_active)
    remove_column :service_points, :work_status
    remove_column :service_points, :is_active
  end
end
