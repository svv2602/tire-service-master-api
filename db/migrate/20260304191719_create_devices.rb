# frozen_string_literal: true

# Migration for mobile device token registration.
# Stores push notification tokens (APNs / FCM) for mobile apps.
class CreateDevices < ActiveRecord::Migration[8.0]
  def change
    create_table :devices do |t|
      t.references :user, null: false, foreign_key: true
      t.string :device_token, null: false
      t.string :platform, null: false # ios, android
      t.string :device_name
      t.string :device_model
      t.string :os_version
      t.string :app_version
      t.boolean :is_active, default: true, null: false
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :devices, :device_token, unique: true
    add_index :devices, [:user_id, :platform]
    add_index :devices, :is_active
  end
end
