class CreateCustomVariables < ActiveRecord::Migration[8.0]
  def change
    create_table :custom_variables do |t|
      t.string :name, null: false, limit: 100
      t.text :description
      t.string :example_value, limit: 255
      t.string :category, null: false, limit: 50
      t.boolean :is_active, null: false, default: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    # Индексы для оптимизации запросов
    add_index :custom_variables, :name, unique: true
    add_index :custom_variables, :category
    add_index :custom_variables, :is_active
    add_index :custom_variables, [:category, :is_active]
  end
end
