class AddPasswordResetToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :password_reset_token, :string
    add_column :users, :password_reset_sent_at, :datetime
    
    # Добавляем индекс для быстрого поиска по токену
    add_index :users, :password_reset_token, unique: true
    
    # Добавляем комментарии для ясности
    change_column_comment :users, :password_reset_token, 'Токен для восстановления пароля'
    change_column_comment :users, :password_reset_sent_at, 'Время истечения токена восстановления пароля'
  end
end
