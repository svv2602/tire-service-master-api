class CreatePushSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :push_subscriptions do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.text :endpoint, null: false
      t.text :p256dh_key, null: false
      t.text :auth_key, null: false
      t.text :user_agent
      t.boolean :is_active, default: true, null: false
      t.datetime :last_used_at
      t.integer :notifications_sent, default: 0
      t.integer :notifications_failed, default: 0

      t.timestamps
    end
    
    # Индексы для оптимизации запросов
    add_index :push_subscriptions, :is_active
    add_index :push_subscriptions, :endpoint, unique: true
    add_index :push_subscriptions, [:user_id, :is_active]
  end
end
