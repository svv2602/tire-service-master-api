class CreateSchedulingTables < ActiveRecord::Migration[8.0]
  def change
    # Шаблоны расписания по дням недели
    create_table :schedule_templates do |t|
      t.references :service_point, null: false, foreign_key: true
      t.references :weekday, null: false, foreign_key: true
      t.time :opening_time, null: false
      t.time :closing_time, null: false
      t.boolean :is_working_day, default: true
      t.timestamps
    end
    add_index :schedule_templates, [:service_point_id, :weekday_id], unique: true, name: 'idx_unique_service_point_weekday'

    # Исключения из расписания (праздники, особые дни)
    create_table :schedule_exceptions do |t|
      t.references :service_point, null: false, foreign_key: true
      t.date :exception_date, null: false
      t.boolean :is_closed, default: true
      t.time :opening_time
      t.time :closing_time
      t.string :reason
      t.timestamps
    end
    add_index :schedule_exceptions, [:service_point_id, :exception_date], unique: true, name: 'idx_unique_service_point_exception_date'

    # Слоты расписания
    create_table :schedule_slots do |t|
      t.references :service_point, null: false, foreign_key: true
      t.date :slot_date, null: false
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.integer :post_number, null: false
      t.boolean :is_available, default: true
      t.boolean :is_special, default: false
      t.string :special_description
      t.timestamps
    end
    add_index :schedule_slots, :is_available, name: 'idx_schedule_slots_availability'
    add_index :schedule_slots, [:service_point_id, :slot_date, :start_time, :post_number], unique: true, name: 'idx_unique_slot'
  end
end
