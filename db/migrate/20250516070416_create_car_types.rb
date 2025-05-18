class CreateCarTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :car_types do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :is_active, default: true

      t.timestamps
    end
    
    # Добавляем индекс для уникальности имени типа автомобиля
    add_index :car_types, :name, unique: true
    
    # Добавляем начальные данные для типов автомобилей
    reversible do |dir|
      dir.up do
        execute <<-SQL
          INSERT INTO car_types (name, description, is_active, created_at, updated_at) VALUES
          ('Sedan', 'Standard sedan passenger car', true, NOW(), NOW()),
          ('SUV', 'Sport utility vehicle', true, NOW(), NOW()),
          ('Van', 'Passenger or cargo van', true, NOW(), NOW()),
          ('Pickup', 'Pickup truck', true, NOW(), NOW()),
          ('Hatchback', 'Hatchback passenger car', true, NOW(), NOW()),
          ('Estate', 'Estate/wagon passenger car', true, NOW(), NOW()),
          ('Crossover', 'Crossover utility vehicle', true, NOW(), NOW()),
          ('Minivan', 'Minivan passenger vehicle', true, NOW(), NOW()),
          ('Sports car', 'Performance sports car', true, NOW(), NOW());
        SQL
      end
    end
  end
end
