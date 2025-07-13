class AddIsServiceBookingToBookings < ActiveRecord::Migration[8.0]
  def change
    add_column :bookings, :is_service_booking, :boolean, default: false, null: false
    add_index :bookings, :is_service_booking
  end
end
