class CreateTireOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :tire_orders do |t|
      t.references :user, null: false, foreign_key: true
      t.references :supplier, null: false, foreign_key: true
      t.string :status, null: false, default: 'draft'
      t.string :client_name, null: false
      t.string :client_phone, null: false
      t.text :comment
      t.decimal :total_amount, precision: 10, scale: 2, default: 0.0

      t.timestamps
    end

    add_index :tire_orders, [:user_id, :status]
    add_index :tire_orders, [:supplier_id, :status]
    add_index :tire_orders, :status
  end
end
