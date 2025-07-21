class CreateTelegramNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :telegram_notifications do |t|
      t.text :message, null: false
      t.string :chat_id, null: false
      t.references :user, null: false, foreign_key: true
      t.references :booking, null: true, foreign_key: true
      t.string :notification_type, default: 'general'
      t.string :status, default: 'pending'
      t.datetime :sent_at
      t.text :error_message
      t.integer :retry_count, default: 0
      t.json :telegram_response
      t.integer :message_id

      t.timestamps
    end
    
    add_index :telegram_notifications, :chat_id
    add_index :telegram_notifications, :notification_type
    add_index :telegram_notifications, :status
    add_index :telegram_notifications, :sent_at
  end
end
