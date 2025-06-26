class MakeServiceCategoryRequiredInPosts < ActiveRecord::Migration[8.0]
  def change
    change_column_null :service_posts, :service_category_id, false
  end
end
