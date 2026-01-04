# frozen_string_literal: true

class AddQrCodeToOrders < ActiveRecord::Migration[8.0]
  def change
    # Add QR code token for order pickup verification
    add_column :orders, :qr_code_token, :string
    add_column :orders, :qr_scanned_at, :datetime
    add_column :orders, :qr_scanned_by_id, :bigint

    add_index :orders, :qr_code_token, unique: true
    add_foreign_key :orders, :users, column: :qr_scanned_by_id

    # Also add to tire_orders
    add_column :tire_orders, :qr_code_token, :string
    add_column :tire_orders, :qr_scanned_at, :datetime
    add_column :tire_orders, :qr_scanned_by_id, :bigint

    add_index :tire_orders, :qr_code_token, unique: true
    add_foreign_key :tire_orders, :users, column: :qr_scanned_by_id
  end
end
