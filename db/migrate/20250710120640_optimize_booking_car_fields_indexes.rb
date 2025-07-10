class OptimizeBookingCarFieldsIndexes < ActiveRecord::Migration[8.0]
  def change
    # Индексы для полей car_brand, car_model, license_plate уже существуют в schema.rb:
    # - index_bookings_on_car_brand_model
    # - index_bookings_on_license_plate
    # Дополнительные индексы не требуются
  end
end
