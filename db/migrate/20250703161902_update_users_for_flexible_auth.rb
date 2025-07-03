class UpdateUsersForFlexibleAuth < ActiveRecord::Migration[8.0]
  def up
    # Делаем phone nullable (если сейчас not null)
    change_column_null :users, :phone, true
    
    # Добавляем комментарий для ясности
    change_column_comment :users, :phone, 'Номер телефона (один из email/phone обязателен)'
    
    puts "✅ Поле phone теперь может быть NULL"
    puts "✅ Добавлен комментарий к полю phone"
    puts "ℹ️  Теперь пользователи могут регистрироваться только с email или только с телефоном"
  end
  
  def down
    # При откате возвращаем phone как обязательное поле
    # Сначала проверяем, есть ли пользователи без телефона
    users_without_phone = User.where(phone: [nil, ''])
    
    if users_without_phone.exists?
      puts "⚠️  Найдены пользователи без телефона:"
      users_without_phone.each do |user|
        puts "   - ID: #{user.id}, Email: #{user.email}"
      end
      
      raise ActiveRecord::IrreversibleMigration, 
            "Нельзя откатить миграцию: есть пользователи без телефона. " \
            "Сначала добавьте им номера телефонов или удалите их."
    end
    
    change_column_null :users, :phone, false
    change_column_comment :users, :phone, nil
    
    puts "✅ Поле phone снова обязательно"
  end
end
