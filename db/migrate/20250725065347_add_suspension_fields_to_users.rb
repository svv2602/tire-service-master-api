class AddSuspensionFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :is_suspended, :boolean, null: false, default: false, 
               comment: 'Флаг блокировки пользователя'
    add_column :users, :suspended_until, :datetime, null: true, 
               comment: 'Дата окончания блокировки (null = бессрочно)'
    add_column :users, :suspension_reason, :text, null: true, 
               comment: 'Причина блокировки'
    add_reference :users, :suspended_by, null: true, foreign_key: { to_table: :users }, 
                  comment: 'Кто заблокировал пользователя'
    add_column :users, :suspended_at, :datetime, null: true, 
               comment: 'Дата и время блокировки'

    # Индексы для оптимизации запросов
    add_index :users, :is_suspended
    add_index :users, :suspended_until
  end
end
