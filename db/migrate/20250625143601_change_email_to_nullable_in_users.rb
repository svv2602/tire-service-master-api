class ChangeEmailToNullableInUsers < ActiveRecord::Migration[8.0]
  def change
    # Изменяем колонку email, чтобы разрешить NULL значения
    change_column_null :users, :email, true
    
    # Также добавляем комментарий для ясности
    change_column_comment :users, :email, 'Email пользователя (необязательное поле)'
  end
end
