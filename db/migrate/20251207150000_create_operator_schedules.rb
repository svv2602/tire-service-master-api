# frozen_string_literal: true

class CreateOperatorSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :operator_schedules do |t|
      t.references :operator, null: false, foreign_key: true
      t.references :service_point, null: false, foreign_key: true
      t.date :schedule_date, null: false
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.string :shift_type, default: 'regular' # regular, overtime, replacement
      t.text :notes
      t.boolean :is_confirmed, default: false
      t.references :confirmed_by, foreign_key: { to_table: :users }
      t.datetime :confirmed_at

      t.timestamps
    end

    add_index :operator_schedules, [:operator_id, :schedule_date]
    add_index :operator_schedules, [:service_point_id, :schedule_date]
    add_index :operator_schedules, [:schedule_date, :service_point_id]
    add_index :operator_schedules, :shift_type
  end
end
