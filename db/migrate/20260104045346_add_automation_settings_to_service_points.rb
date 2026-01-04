# frozen_string_literal: true

class AddAutomationSettingsToServicePoints < ActiveRecord::Migration[8.0]
  def change
    add_column :service_points, :automation_settings, :jsonb, default: {}, null: false, comment: 'Automation settings: auto_confirm_enabled, auto_confirm_delay_minutes, auto_assign_operator, send_confirmation_sms, auto_confirm_conditions'

    add_index :service_points, :automation_settings, using: :gin
  end
end
