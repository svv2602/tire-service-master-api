class CreateCarTables < ActiveRecord::Migration[8.0]
  def change
    # Бренды автомобилей
    create_table :car_brands do |t|
      t.string :name, null: false
      t.string :logo_url
      t.boolean :is_active, default: true
      t.timestamps
    end
    add_index :car_brands, :name, unique: true

    # Модели автомобилей
    create_table :car_models do |t|
      t.references :brand, null: false, foreign_key: { to_table: :car_brands }
      t.string :name, null: false
      t.boolean :is_active, default: true
      t.timestamps
    end
    add_index :car_models, [:brand_id, :name], unique: true

    # Типы шин
    create_table :tire_types do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :is_active, default: true
      t.timestamps
    end

    # Добавляем начальные данные для типов шин
    reversible do |dir|
      dir.up do
        execute <<-SQL
          INSERT INTO tire_types (name, description, is_active, created_at, updated_at) VALUES
          ('Summer', 'Tires designed for warm weather conditions', true, NOW(), NOW()),
          ('Winter', 'Tires designed for snow and ice conditions', true, NOW(), NOW()),
          ('All Season', 'Tires designed for year-round use', true, NOW(), NOW()),
          ('Performance', 'High-performance tires for sporty driving', true, NOW(), NOW()),
          ('Off-Road', 'Tires designed for off-road conditions', true, NOW(), NOW());
        SQL
      end
    end

    # Автомобили клиентов
    create_table :client_cars do |t|
      t.references :client, null: false, foreign_key: true
      t.references :brand, null: false, foreign_key: { to_table: :car_brands }
      t.references :model, null: false, foreign_key: { to_table: :car_models }
      t.integer :year
      t.references :tire_type, foreign_key: true
      t.string :tire_size
      t.text :notes
      t.boolean :is_primary, default: false
      t.timestamps
    end
  end
end
