class AddSlotFieldsToBookings < ActiveRecord::Migration[8.0]
  def change
    # Add session_id for linking with slot reservations
    add_column :bookings, :booking_session_id, :string

    # Add service_post_id for tracking which post the booking is on
    add_reference :bookings, :service_post, foreign_key: true, null: true

    # Store reserved slot IDs (for multi-slot bookings)
    add_column :bookings, :reserved_slot_ids, :jsonb, default: []

    # Add calculated duration based on services
    add_column :bookings, :calculated_duration_minutes, :integer

    # Add indexes
    add_index :bookings, :booking_session_id
  end
end
