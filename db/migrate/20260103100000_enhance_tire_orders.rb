class EnhanceTireOrders < ActiveRecord::Migration[8.0]
  def change
    change_table :tire_orders do |t|
      # Partner association for supplier order tracking
      t.references :partner, foreign_key: true, index: true

      # Shipping information
      t.string :tracking_number
      t.datetime :shipped_at
      t.datetime :delivered_at

      # Additional notes for supplier
      t.text :notes
    end

    # Composite index for supplier dashboard queries
    add_index :tire_orders, [:supplier_id, :created_at], name: 'idx_tire_orders_supplier_created'
    add_index :tire_orders, [:partner_id, :status], name: 'idx_tire_orders_partner_status'
  end
end
