class RemovePhotoUrlFromServicePointPhotos < ActiveRecord::Migration[8.0]
  def change
    remove_column :service_point_photos, :photo_url, :string
  end
end
