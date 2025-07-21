class CreateTelegramBookingSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :telegram_booking_sessions do |t|
      t.string :chat_id, null: false
      t.string :current_step, null: false, default: 'city_selection'
      t.json :session_data, default: {}
      t.datetime :expires_at, null: false

      t.timestamps
    end
    
    add_index :telegram_booking_sessions, :chat_id, unique: true
    add_index :telegram_booking_sessions, :expires_at
  end
end
