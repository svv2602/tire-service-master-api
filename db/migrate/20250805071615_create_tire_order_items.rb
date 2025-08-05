class CreateTireOrderItems < ActiveRecord::Migration[8.0]
  def change
    create_table :tire_order_items do |t|
      t.references :tire_order, null: false, foreign_key: true
      t.references :supplier_tire_product, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1
      t.decimal :price_at_order, precision: 10, scale: 2, null: false

      t.timestamps
    end

    # Уникальный индекс - один товар может быть только один раз в одном заказе
    add_index :tire_order_items, [:tire_order_id, :supplier_tire_product_id], 
              unique: true, name: 'index_tire_order_items_unique'
  end
end
