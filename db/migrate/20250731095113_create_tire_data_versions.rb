class CreateTireDataVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :tire_data_versions do |t|
      t.string :version, null: false
      t.text :source_description
      t.jsonb :file_checksums
      t.jsonb :statistics
      t.datetime :imported_at
      t.boolean :is_active, default: true

      t.timestamps
    end
    
    # Индексы для оптимизации
    add_index :tire_data_versions, :version, unique: true
    add_index :tire_data_versions, :is_active
    add_index :tire_data_versions, :imported_at
    
    # Создаем начальную версию данных
    reversible do |dir|
      dir.up do
        execute <<-SQL
          INSERT INTO tire_data_versions (version, source_description, statistics, imported_at, is_active, created_at, updated_at) VALUES
          ('2025.1', 'Базовая версия данных шин', '{"brands": 0, "models": 0, "configurations": 0}', NOW(), true, NOW(), NOW());
        SQL
      end
    end
  end
end
