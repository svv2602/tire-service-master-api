class CreateGeographicData < ActiveRecord::Migration[8.0]
  def change
    # Таблица регионов
    create_table :regions do |t|
      t.string :name, null: false
      t.string :code
      t.boolean :is_active, default: true
      t.timestamps
    end
    add_index :regions, :name, unique: true
    add_index :regions, :code, unique: true

    # Таблица городов
    create_table :cities do |t|
      t.references :region, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :is_active, default: true
      t.timestamps
    end
    add_index :cities, [:region_id, :name], unique: true
  end
end
