class AddImageUrlToOrderItems < ActiveRecord::Migration[8.0]
  def change
    add_column :order_items, :image_url, :string, comment: 'Ссылка на изображение товара (опционально)'
    add_index :order_items, [:artikul, :image_url], name: 'index_order_items_on_artikul_and_image_url'
  end
end
