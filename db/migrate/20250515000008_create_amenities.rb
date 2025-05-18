class CreateAmenities < ActiveRecord::Migration[8.0]
  def change
    create_table :amenities do |t|
      t.string :name, null: false
      t.string :icon
      t.timestamps
    end

    create_table :service_point_amenities do |t|
      t.references :service_point, null: false, foreign_key: true
      t.references :amenity, null: false, foreign_key: true
      t.timestamps
    end
    add_index :service_point_amenities, [:service_point_id, :amenity_id], unique: true, name: 'idx_unique_service_point_amenity'

    # Добавляем начальные данные для amenities
    reversible do |dir|
      dir.up do
        execute <<-SQL
          INSERT INTO amenities (name, icon, created_at, updated_at) VALUES
          ('Wi-Fi', 'wifi', NOW(), NOW()),
          ('Waiting area', 'chair', NOW(), NOW()),
          ('Coffee/Tea', 'coffee', NOW(), NOW()),
          ('TV', 'tv', NOW(), NOW()),
          ('Restroom', 'toilet', NOW(), NOW()),
          ('Parking available', 'parking', NOW(), NOW()),
          ('Air conditioning', 'air_conditioner', NOW(), NOW()),
          ('Child-friendly', 'child_friendly', NOW(), NOW());
        SQL
      end
    end
  end
end
