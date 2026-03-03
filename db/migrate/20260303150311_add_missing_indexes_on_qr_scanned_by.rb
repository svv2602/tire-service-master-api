# Add missing indexes on foreign key columns qr_scanned_by_id.
# These FK columns reference users table but had no index, causing full table scans.
class AddMissingIndexesOnQrScannedBy < ActiveRecord::Migration[7.0]
  def change
    add_index :orders, :qr_scanned_by_id, if_not_exists: true
    add_index :tire_orders, :qr_scanned_by_id, if_not_exists: true
  end
end
