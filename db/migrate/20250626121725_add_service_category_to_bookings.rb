class AddServiceCategoryToBookings < ActiveRecord::Migration[8.0]
  def change
    add_reference :bookings, :service_category, null: true, foreign_key: true
  end
end
