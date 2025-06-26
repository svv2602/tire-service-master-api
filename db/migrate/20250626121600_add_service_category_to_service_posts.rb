class AddServiceCategoryToServicePosts < ActiveRecord::Migration[8.0]
  def change
    add_reference :service_posts, :service_category, null: true, foreign_key: true
    add_index :service_posts, [:service_point_id, :service_category_id]
  end
end
