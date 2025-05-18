class CreateServicePointPhotos < ActiveRecord::Migration[8.0]
  def change
    create_table :service_point_photos do |t|
      t.references :service_point, null: false, foreign_key: true
      t.string :photo_url, null: false
      t.integer :sort_order, default: 0
      t.timestamps
    end
  end
end
