class AddServiceRecipientInfoToBookings < ActiveRecord::Migration[8.0]
  def change
    # Добавляем поля для информации о получателе услуги
    # (может отличаться от того, кто оформил бронирование)
    add_column :bookings, :service_recipient_first_name, :string, 
               comment: 'Имя получателя услуги'
    add_column :bookings, :service_recipient_last_name, :string,
               comment: 'Фамилия получателя услуги' 
    add_column :bookings, :service_recipient_phone, :string,
               comment: 'Телефон получателя услуги для связи'
    add_column :bookings, :service_recipient_email, :string,
               comment: 'Email получателя услуги (опционально)'
    
    # Добавляем индекс для поиска по телефону получателя услуги
    add_index :bookings, :service_recipient_phone, 
              name: 'index_bookings_on_service_recipient_phone'
  end
end
