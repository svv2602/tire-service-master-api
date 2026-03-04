# Phase-03: Enable PostGIS extension and add geographic location column to service_points
# This replaces the Haversine-based SQL calculations with native PostGIS spatial queries
# for significantly faster geo-search performance at scale (>1000 service points).
class EnablePostgisAndAddLocationToServicePoints < ActiveRecord::Migration[8.0]
  def change
    # Enable PostGIS extension (idempotent — safe to run multiple times)
    enable_extension 'postgis'

    # Add geographic point column with SRID 4326 (WGS84 — standard GPS coordinate system)
    add_column :service_points, :location, :st_point, geographic: true, srid: 4326

    # GiST index for efficient spatial queries (ST_DWithin, ST_Distance, etc.)
    add_index :service_points, :location, using: :gist, name: 'idx_service_points_location_gist'
  end
end
