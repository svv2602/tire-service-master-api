class CreateSuppliers < ActiveRecord::Migration[8.0]
  def change
    create_table :suppliers do |t|
      t.string :firm_id, null: false, limit: 50
      t.string :name, null: false, limit: 255
      t.string :api_key, null: false, limit: 255
      t.boolean :is_active, default: true
      t.integer :priority, default: 0
      t.timestamp :last_sync_at

      t.timestamps
    end
    
    # Индексы
    add_index :suppliers, :firm_id, unique: true
    add_index :suppliers, :api_key, unique: true
    add_index :suppliers, :is_active
  end
end
