class AddRecommendToReviews < ActiveRecord::Migration[8.0]
  def change
    add_column :reviews, :recommend, :boolean, default: true, null: false
    add_index :reviews, :recommend
  end
end
