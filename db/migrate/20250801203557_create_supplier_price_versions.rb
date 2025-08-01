class CreateSupplierPriceVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :supplier_price_versions do |t|
      t.references :supplier, null: false, foreign_key: true
      t.string :version, null: false, limit: 100
      t.string :file_checksum, limit: 64
      t.integer :products_count, default: 0
      t.integer :processed_count, default: 0
      t.integer :errors_count, default: 0
      t.integer :processing_time_ms
      t.timestamp :uploaded_at, default: -> { 'CURRENT_TIMESTAMP' }

      t.timestamps
    end
    
    # Индексы
    add_index :supplier_price_versions, [:supplier_id, :version], unique: true
    add_index :supplier_price_versions, :uploaded_at
    # supplier_id индекс уже создается автоматически для foreign_key
  end
end
