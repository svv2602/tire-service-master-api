class CreateBookingConflicts < ActiveRecord::Migration[8.0]
  def change
    create_table :booking_conflicts do |t|
      t.references :booking, null: false, foreign_key: true
      t.string :conflict_type, null: false # 'schedule_change', 'service_point_status', 'post_status'
      t.text :conflict_reason, null: false
      t.datetime :detected_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.datetime :resolved_at, null: true
      t.string :resolution_type, null: true # 'auto_reschedule', 'manual_reschedule', 'cancel', 'ignore'
      t.text :resolution_notes, null: true
      t.references :resolved_by, null: true, foreign_key: { to_table: :users }
      t.string :status, null: false, default: 'pending' # 'pending', 'resolved', 'ignored'

      t.timestamps
    end

    # Индексы для быстрого поиска
    add_index :booking_conflicts, :status
    add_index :booking_conflicts, :conflict_type
    add_index :booking_conflicts, :detected_at
    add_index :booking_conflicts, [:booking_id, :status]
  end
end
