class UpdateBookingsForDynamicSchedule < ActiveRecord::Migration[8.0]
  def up
    # Сначала заполняем поля booking_date, start_time, end_time из связанных слотов
    populate_booking_times_from_slots
    
    # Делаем поля обязательными
    change_column_null :bookings, :booking_date, false
    change_column_null :bookings, :start_time, false  
    change_column_null :bookings, :end_time, false
    
    # Удаляем связь с slot_id (если она есть)
    if column_exists?(:bookings, :slot_id)
      remove_column :bookings, :slot_id
    end
    
    # Добавляем индексы для оптимизации запросов
    add_index :bookings, [:service_point_id, :booking_date, :start_time], 
              name: 'idx_bookings_service_point_date_time'
    add_index :bookings, [:booking_date, :start_time, :end_time], 
              name: 'idx_bookings_time_range'
  end
  
  def down
    # Обратная миграция - восстанавливаем slot_id связь
    add_reference :bookings, :slot, null: true, foreign_key: { to_table: :schedule_slots }
    
    # Убираем обязательность полей времени
    change_column_null :bookings, :booking_date, true
    change_column_null :bookings, :start_time, true
    change_column_null :bookings, :end_time, true
    
    # Удаляем добавленные индексы
    remove_index :bookings, name: 'idx_bookings_service_point_date_time' if index_exists?(:bookings, [:service_point_id, :booking_date, :start_time])
    remove_index :bookings, name: 'idx_bookings_time_range' if index_exists?(:bookings, [:booking_date, :start_time, :end_time])
  end
  
  private
  
  def populate_booking_times_from_slots
    # Заполняем данные о времени из связанных слотов для существующих бронирований
    execute <<~SQL
      UPDATE bookings 
      SET 
        booking_date = schedule_slots.slot_date,
        start_time = schedule_slots.start_time,
        end_time = schedule_slots.end_time
      FROM schedule_slots 
      WHERE bookings.slot_id = schedule_slots.id 
        AND (bookings.booking_date IS NULL 
             OR bookings.start_time IS NULL 
             OR bookings.end_time IS NULL)
    SQL
  end
end
