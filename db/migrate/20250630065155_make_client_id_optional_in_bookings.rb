class MakeClientIdOptionalInBookings < ActiveRecord::Migration[8.0]
  def change
    # Изменяем поле client_id на nullable для поддержки гостевых бронирований
    change_column_null :bookings, :client_id, true
    
    # Добавляем индекс для быстрого поиска гостевых бронирований
    add_index :bookings, :service_recipient_phone, name: 'index_bookings_on_guest_phone'
    
    # Добавляем индекс для фильтрации по типу бронирования
    add_index :bookings, :client_id, where: 'client_id IS NULL', name: 'index_bookings_guest_only'
  end
end
