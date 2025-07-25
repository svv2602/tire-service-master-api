class EnhanceSystemLogsTable < ActiveRecord::Migration[8.0]
  def change
    # Переименовываем entity_type в resource_type для единообразия
    rename_column :system_logs, :entity_type, :resource_type
    rename_column :system_logs, :entity_id, :resource_id
    
    # Добавляем новые поля для расширенного аудита
    add_column :system_logs, :changes, :jsonb, comment: 'Детальные изменения в JSON формате'
    add_column :system_logs, :additional_data, :jsonb, comment: 'Дополнительная контекстная информация'
    
    # Добавляем комментарии к существующим полям (без изменения типов)
    change_column_comment :system_logs, :action, 'Тип действия (created/updated/deleted/suspended/assigned)'
    change_column_comment :system_logs, :resource_type, 'Тип ресурса (User/Booking/ServicePoint/Operator)'
    change_column_comment :system_logs, :resource_id, 'ID ресурса'
    change_column_comment :system_logs, :ip_address, 'IP адрес пользователя'
    change_column_comment :system_logs, :user_agent, 'User-Agent браузера'
    
    # Добавляем новые индексы для улучшения производительности
    add_index :system_logs, :changes, using: :gin
    add_index :system_logs, :additional_data, using: :gin
    add_index :system_logs, [:resource_type, :action]
    add_index :system_logs, [:user_id, :created_at]
    
    # Переименовываем существующий индекс
    remove_index :system_logs, name: 'idx_system_logs_entity'
    add_index :system_logs, [:resource_type, :resource_id], name: 'idx_system_logs_resource'
  end
end
