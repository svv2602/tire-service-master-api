# Migration to create webhook_deliveries table for tracking webhook delivery attempts
class CreateWebhookDeliveries < ActiveRecord::Migration[8.0]
  def change
    create_table :webhook_deliveries do |t|
      t.references :webhook_endpoint, null: false, foreign_key: true
      t.string :event, null: false
      t.jsonb :payload, default: {}, null: false
      t.string :status, default: 'pending', null: false
      t.integer :response_code
      t.text :response_body
      t.integer :attempt, default: 0, null: false
      t.datetime :delivered_at
      t.text :error_message

      t.timestamps
    end

    add_index :webhook_deliveries, :event
    add_index :webhook_deliveries, :status
    add_index :webhook_deliveries, :created_at
  end
end
