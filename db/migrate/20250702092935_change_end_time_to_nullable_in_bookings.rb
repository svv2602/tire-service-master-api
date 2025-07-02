class ChangeEndTimeToNullableInBookings < ActiveRecord::Migration[8.0]
  def up
    # Изменяем поле end_time - делаем его nullable для слотовой архитектуры
    change_column_null :bookings, :end_time, true
    
    # Добавляем комментарий
    change_column_comment :bookings, :end_time, 
      "Время окончания бронирования. NULL в слотовой архитектуре - заполняется при назначении поста"
  end

  def down
    # Откат - делаем поле обязательным обратно
    # Сначала заполняем NULL значения фиктивными данными
    execute <<-SQL
      UPDATE bookings 
      SET end_time = start_time + INTERVAL '60 minutes' 
      WHERE end_time IS NULL;
    SQL
    
    change_column_null :bookings, :end_time, false
    change_column_comment :bookings, :end_time, nil
  end
end
