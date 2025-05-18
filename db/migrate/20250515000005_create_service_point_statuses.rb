class CreateServicePointStatuses < ActiveRecord::Migration[8.0]
  def change
    create_table :service_point_statuses do |t|
      t.string :name, null: false, index: { unique: true }
      t.text :description
      t.string :color, limit: 7 # Hex code для UI
      t.boolean :is_active, default: true
      t.integer :sort_order, default: 0
      t.timestamps
    end

    # Добавляем начальные данные для статусов
    reversible do |dir|
      dir.up do
        execute <<-SQL
          INSERT INTO service_point_statuses (name, description, color, is_active, sort_order, created_at, updated_at) VALUES
          ('active', 'Service point is operating normally', '#4CAF50', true, 1, NOW(), NOW()),
          ('temporarily_closed', 'Service point is temporarily closed', '#FFC107', true, 2, NOW(), NOW()),
          ('closed', 'Service point is permanently closed', '#F44336', true, 3, NOW(), NOW()),
          ('maintenance', 'Service point is under maintenance', '#2196F3', true, 4, NOW(), NOW());
        SQL
      end
    end
  end
end
