class AddDescriptionToPriceLists < ActiveRecord::Migration[8.0]
  def change
    add_column :price_lists, :description, :text
  end
end
