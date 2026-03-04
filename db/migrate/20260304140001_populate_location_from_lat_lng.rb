# Phase-03: Data migration — populate `location` column from existing latitude/longitude.
# Runs in batches to avoid locking the table for a long time.
class PopulateLocationFromLatLng < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    say_with_time "Populating location from latitude/longitude" do
      # Update all service_points that have lat/lng but no location yet
      execute <<~SQL
        UPDATE service_points
        SET location = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography::geometry
        WHERE latitude IS NOT NULL
          AND longitude IS NOT NULL
          AND location IS NULL;
      SQL
    end
  end

  def down
    say_with_time "Clearing location column" do
      execute <<~SQL
        UPDATE service_points SET location = NULL;
      SQL
    end
  end
end
