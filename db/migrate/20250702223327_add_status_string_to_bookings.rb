class AddStatusStringToBookings < ActiveRecord::Migration[8.0]
  def up
    # Добавляем новое поле status типа string
    add_column :bookings, :status, :string
    
    # Добавляем индекс для поля status
    add_index :bookings, :status
    
    # Заполняем новое поле данными из существующих статусов
    # Маппинг ID статусов к строковым значениям
    status_mapping = {
      9 => 'pending',           # В ожидании
      10 => 'confirmed',        # Подтверждено
      11 => 'in_progress',      # В процессе
      12 => 'completed',        # Завершено
      13 => 'cancelled_by_client',   # Отменено клиентом
      14 => 'cancelled_by_partner',  # Отменено партнером
      15 => 'no_show'          # Не явился
    }
    
    # Обновляем записи
    status_mapping.each do |status_id, status_name|
      execute <<-SQL
        UPDATE bookings 
        SET status = '#{status_name}' 
        WHERE status_id = #{status_id}
      SQL
    end
    
    # Устанавливаем значение по умолчанию для записей без статуса
    execute <<-SQL
      UPDATE bookings 
      SET status = 'pending' 
      WHERE status IS NULL
    SQL
    
    # Делаем поле обязательным
    change_column_null :bookings, :status, false
    
    # Устанавливаем значение по умолчанию
    change_column_default :bookings, :status, 'pending'
  end

  def down
    # Удаляем индекс
    remove_index :bookings, :status if index_exists?(:bookings, :status)
    
    # Удаляем колонку
    remove_column :bookings, :status
  end
end
