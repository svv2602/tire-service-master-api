class CreateSupplierTireProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :supplier_tire_products do |t|
      t.references :supplier, null: false, foreign_key: true
      t.string :external_id, null: false, limit: 255
      t.string :brand, null: false, limit: 100
      t.string :brand_normalized, null: false, limit: 100
      t.string :model, null: false, limit: 255
      t.string :name, null: false, limit: 500
      t.integer :width, null: false
      t.integer :height, null: false
      t.string :diameter, null: false, limit: 10
      t.string :load_index, limit: 10
      t.string :speed_index, limit: 10
      t.string :season, null: false, limit: 20
      t.decimal :price_uah, precision: 10, scale: 2
      t.string :stock_status, limit: 50
      t.boolean :in_stock, default: false
      t.text :description
      t.string :image_url, limit: 1000
      t.string :product_url, limit: 1000
      t.string :country, limit: 100
      t.string :year_week, limit: 20
      t.text :search_tokens
      t.jsonb :raw_data

      t.timestamps
    end
    
    # Индексы для быстрого поиска
    add_index :supplier_tire_products, 
              [:brand_normalized, :width, :height, :diameter, :season, :in_stock], 
              name: 'idx_supplier_tire_products_search'
    
    # Полнотекстовый поиск
    add_index :supplier_tire_products, 
              "to_tsvector('russian', search_tokens)", 
              using: :gin, 
              name: 'idx_supplier_tire_products_tokens'
    
    # Уникальность товара у поставщика
    add_index :supplier_tire_products, [:supplier_id, :external_id], unique: true
    
    # Дополнительные индексы (supplier_id уже создается автоматически для foreign_key)
    add_index :supplier_tire_products, :in_stock
    add_index :supplier_tire_products, :season
    add_index :supplier_tire_products, :brand_normalized
  end
end
