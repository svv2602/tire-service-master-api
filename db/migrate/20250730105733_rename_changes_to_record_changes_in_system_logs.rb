class RenameChangesToRecordChangesInSystemLogs < ActiveRecord::Migration[8.0]
  def change
    # Переименовываем поле changes в record_changes для избежания конфликта с методом ActiveRecord
    rename_column :system_logs, :changes, :record_changes
    
    # Обновляем индексы (только те, что существуют)
    remove_index :system_logs, name: "idx_system_logs_changes_gin" if index_exists?(:system_logs, :changes, name: "idx_system_logs_changes_gin")
    
    add_index :system_logs, :record_changes, using: :gin, name: "idx_system_logs_record_changes_gin"
    
    # Обновляем комментарий
    change_column_comment :system_logs, :record_changes, 'Детальные изменения записи в JSON формате'
  end
end
