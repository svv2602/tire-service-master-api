class CreateManagerServicePointsAndWeekdays < ActiveRecord::Migration[8.0]
  def change
    create_table :manager_service_points do |t|
      t.references :manager, null: false, foreign_key: true
      t.references :service_point, null: false, foreign_key: true
      t.timestamps
    end
    add_index :manager_service_points, [:manager_id, :service_point_id], unique: true, name: 'idx_unique_manager_service_point'

    create_table :weekdays do |t|
      t.string :name, null: false
      t.string :short_name, null: false, limit: 3
      t.integer :sort_order, null: false
    end

    # Добавляем начальные данные для дней недели
    reversible do |dir|
      dir.up do
        execute <<-SQL
          INSERT INTO weekdays (name, short_name, sort_order) VALUES
          ('Monday', 'Mon', 1),
          ('Tuesday', 'Tue', 2),
          ('Wednesday', 'Wed', 3),
          ('Thursday', 'Thu', 4),
          ('Friday', 'Fri', 5),
          ('Saturday', 'Sat', 6),
          ('Sunday', 'Sun', 7);
        SQL
      end
    end
  end
end
