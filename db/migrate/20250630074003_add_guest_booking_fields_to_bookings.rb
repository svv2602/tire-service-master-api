class AddGuestBookingFieldsToBookings < ActiveRecord::Migration[8.0]
  def change
    # ✅ Поля для данных автомобиля в гостевых бронированиях
    add_column :bookings, :car_brand, :string, comment: 'Марка автомобиля для гостевых бронирований'
    add_column :bookings, :car_model, :string, comment: 'Модель автомобиля для гостевых бронирований'
    add_column :bookings, :license_plate, :string, comment: 'Номер автомобиля для гостевых бронирований'
    
    # ✅ Индексы для поиска гостевых бронирований по данным автомобиля
    add_index :bookings, :license_plate, name: 'index_bookings_on_license_plate'
    add_index :bookings, [:car_brand, :car_model], name: 'index_bookings_on_car_brand_model'
  end
end
