class AddPriorityAndCategoryToNotifications < ActiveRecord::Migration[8.0]
  def change
    add_column :notifications, :priority, :string, default: 'normal', null: false
    add_column :notifications, :category, :string, default: 'general', null: false
    
    # Добавляем индексы для быстрого поиска
    add_index :notifications, :priority
    add_index :notifications, :category
    
    # Обновляем существующие записи (если есть)
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE notifications 
          SET priority = 'normal', category = 'general' 
          WHERE priority IS NULL OR category IS NULL;
        SQL
      end
    end
  end
end
