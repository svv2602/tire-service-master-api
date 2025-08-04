class CreateSystemSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :system_settings do |t|
      t.string :key, null: false
      t.text :value
      t.text :description
      t.string :category, default: 'general'
      t.string :setting_type, default: 'string'
      t.text :default_value
      t.string :updated_by
      t.boolean :is_encrypted, default: false

      t.timestamps
    end
    
    add_index :system_settings, :key, unique: true
    add_index :system_settings, :category
    add_index :system_settings, [:category, :setting_type]
  end
end
