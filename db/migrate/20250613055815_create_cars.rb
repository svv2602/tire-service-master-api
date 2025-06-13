class CreateCars < ActiveRecord::Migration[8.0]
  def change
    create_table :cars do |t|
      t.references :client, null: false, foreign_key: true
      t.references :car_type, null: false, foreign_key: true
      t.string :brand
      t.string :model
      t.integer :year
      t.string :license_plate
      t.string :vin
      t.string :color
      t.text :notes
      t.boolean :is_active

      t.timestamps
    end
  end
end
