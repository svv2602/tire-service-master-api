class AddCategoryContactsToServicePoints < ActiveRecord::Migration[8.0]
  def change
    add_column :service_points, :category_contacts, :jsonb, default: {}
    add_index :service_points, :category_contacts, using: :gin
  end
end
