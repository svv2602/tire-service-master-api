class AddIsActiveToPartners < ActiveRecord::Migration[8.0]
  def change
    add_column :partners, :is_active, :boolean, default: true
    
    # Индекс для ускорения запросов с фильтрацией по активности
    add_index :partners, :is_active
  end
end 