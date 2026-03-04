# Migration to create webhook_endpoints table for partner webhook integrations
class CreateWebhookEndpoints < ActiveRecord::Migration[8.0]
  def change
    create_table :webhook_endpoints do |t|
      t.references :partner, null: false, foreign_key: true
      t.string :url, null: false
      t.string :secret, null: false
      t.string :events, array: true, default: [], null: false
      t.boolean :is_active, default: true, null: false
      t.string :description

      t.timestamps
    end

    add_index :webhook_endpoints, :is_active
    add_index :webhook_endpoints, :events, using: :gin
  end
end
