class CreateServicePoints < ActiveRecord::Migration[8.0]
  def change
    create_table :service_points do |t|
      t.references :partner, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.references :city, null: false, foreign_key: true
      t.text :address, null: false
      t.decimal :latitude, precision: 10, scale: 8
      t.decimal :longitude, precision: 11, scale: 8
      t.string :contact_phone
      t.references :status, null: false, foreign_key: { to_table: :service_point_statuses }, default: 1
      t.integer :post_count, default: 1
      t.integer :default_slot_duration, default: 60 # in minutes
      t.decimal :rating, precision: 3, scale: 2, default: 0
      t.integer :total_clients_served, default: 0
      t.decimal :average_rating, precision: 3, scale: 2, default: 0
      t.decimal :cancellation_rate, precision: 5, scale: 2, default: 0
      t.timestamps
    end

    add_index :service_points, [:latitude, :longitude], name: 'idx_service_points_location'
  end
end
