# frozen_string_literal: true

# Add sms_confirmed flag to bookings for guest booking SMS verification flow
class AddSmsConfirmedToBookings < ActiveRecord::Migration[8.0]
  def change
    add_column :bookings, :sms_confirmed, :boolean, default: false, null: false
    add_index :bookings, :sms_confirmed, where: 'client_id IS NULL', name: 'index_bookings_sms_confirmed_guests'
  end
end
