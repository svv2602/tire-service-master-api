# frozen_string_literal: true

class CreateGoogleCalendarSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :google_calendar_settings do |t|
      t.references :partner, null: true, foreign_key: true, index: false
      t.references :service_point, null: true, foreign_key: true, index: false
      t.text :access_token
      t.text :refresh_token
      t.datetime :token_expires_at
      t.string :calendar_id
      t.boolean :sync_enabled, default: true, null: false
      t.boolean :sync_confirmed_only, default: false, null: false

      t.timestamps
    end

    add_index :google_calendar_settings, [:partner_id], unique: true, where: 'partner_id IS NOT NULL'
    add_index :google_calendar_settings, [:service_point_id], unique: true, where: 'service_point_id IS NOT NULL'

    # Add google_calendar_event_id to bookings
    add_column :bookings, :google_calendar_event_id, :string
    add_index :bookings, :google_calendar_event_id
  end
end
