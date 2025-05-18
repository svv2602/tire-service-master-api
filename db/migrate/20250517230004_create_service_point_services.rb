class CreateServicePointServices < ActiveRecord::Migration[8.0]
  def change
    create_table :service_point_services do |t|
      t.references :service_point, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :service_point_services, [:service_point_id, :service_id], unique: true, name: 'idx_service_point_services_unique'
  end
end
