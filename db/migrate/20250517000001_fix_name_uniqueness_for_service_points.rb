class FixNameUniquenessForServicePoints < ActiveRecord::Migration[8.0]
  def change
    # Remove any unique indexes on service_points.name if they exist
    if index_exists?(:service_points, :name)
      remove_index :service_points, :name
    end
    
    # Add a composite unique index instead - this ensures service points can have the same name
    # but only if they belong to different partners
    add_index :service_points, [:partner_id, :name], unique: true, 
              name: 'idx_unique_service_point_name_per_partner'
  end
end
