class CreateSeasonalSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :seasonal_schedules do |t|
      t.references :service_point, null: false, foreign_key: true
      t.string :name, null: false, limit: 255, comment: 'Название сезонного расписания (например, "Летнее расписание", "Новогодние каникулы")'
      t.text :description, comment: 'Описание сезонного расписания'
      t.date :start_date, null: false, comment: 'Дата начала действия сезонного расписания'
      t.date :end_date, null: false, comment: 'Дата окончания действия сезонного расписания'
      t.json :working_hours, null: false, comment: 'JSON с расписанием работы по дням недели в формате {monday: {is_working_day: true, start: "09:00", end: "18:00"}}'
      t.boolean :is_active, default: true, null: false, comment: 'Активно ли сезонное расписание'
      t.integer :priority, default: 0, null: false, comment: 'Приоритет расписания (чем выше число, тем выше приоритет)'
      t.timestamps
    end

    # Индексы для оптимизации запросов
    add_index :seasonal_schedules, [:service_point_id, :start_date, :end_date], name: 'idx_seasonal_schedules_period'
    add_index :seasonal_schedules, [:service_point_id, :is_active], name: 'idx_seasonal_schedules_active'
    add_index :seasonal_schedules, :priority, name: 'idx_seasonal_schedules_priority'
    
    # Проверка корректности дат
    add_check_constraint :seasonal_schedules, 'end_date >= start_date', name: 'check_seasonal_schedules_date_range'
  end
end 