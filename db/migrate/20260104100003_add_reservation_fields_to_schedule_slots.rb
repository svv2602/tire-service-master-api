class AddReservationFieldsToScheduleSlots < ActiveRecord::Migration[8.0]
  def change
    add_column :schedule_slots, :reserved_at, :datetime
    add_column :schedule_slots, :reserved_until, :datetime
    add_column :schedule_slots, :reserved_by_session, :string
    add_column :schedule_slots, :reservation_status, :string, default: 'available'

    add_index :schedule_slots, :reserved_until
    add_index :schedule_slots, :reservation_status
    add_index :schedule_slots, :reserved_by_session
  end
end
