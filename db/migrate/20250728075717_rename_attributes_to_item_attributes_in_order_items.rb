class RenameAttributesToItemAttributesInOrderItems < ActiveRecord::Migration[8.0]
  def change
    # Переименовываем конфликтное поле attributes в item_attributes
    if column_exists?(:order_items, :attributes)
      rename_column :order_items, :attributes, :item_attributes
    end
  end
end
