class AddDescriptionAndIsMainToServicePointPhotos < ActiveRecord::Migration[8.0]
  def change
    add_column :service_point_photos, :description, :text
    add_column :service_point_photos, :is_main, :boolean, default: false, null: false
  end
end
