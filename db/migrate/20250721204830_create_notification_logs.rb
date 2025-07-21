class CreateNotificationLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :notification_logs do |t|
      t.string :notification_type
      t.string :recipient_type
      t.integer :recipient_id
      t.string :recipient_email
      t.string :template_type
      t.integer :template_id
      t.string :status
      t.datetime :sent_at
      t.datetime :delivered_at
      t.datetime :opened_at
      t.datetime :clicked_at
      t.text :error_message
      t.json :metadata

      t.timestamps
    end
  end
end
