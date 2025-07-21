class CreateTelegramSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :telegram_subscriptions do |t|
      t.string :chat_id, null: false
      t.references :user, null: false, foreign_key: true
      t.boolean :is_active, default: true, null: false
      t.string :username
      t.string :first_name
      t.string :last_name
      t.string :language_code, default: 'ru'
      t.text :notification_preferences
      t.datetime :last_interaction_at
      t.string :status, default: 'active'

      t.timestamps
    end
    add_index :telegram_subscriptions, :chat_id, unique: true
  end
end
