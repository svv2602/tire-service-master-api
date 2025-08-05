class CreateTireCartItems < ActiveRecord::Migration[8.0]
  def change
    create_table :tire_cart_items do |t|
      t.references :tire_cart, null: false, foreign_key: true
      t.references :supplier_tire_product, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.decimal :price_at_add, precision: 10, scale: 2, null: false

      t.timestamps
    end

    # Уникальный индекс: один товар может быть только один раз в корзине
    add_index :tire_cart_items, [:tire_cart_id, :supplier_tire_product_id], 
              unique: true, name: 'index_tire_cart_items_unique'
  end
end
