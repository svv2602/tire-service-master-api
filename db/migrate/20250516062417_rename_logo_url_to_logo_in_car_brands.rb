class RenameLogoUrlToLogoInCarBrands < ActiveRecord::Migration[8.0]
  def change
    rename_column :car_brands, :logo_url, :logo
  end
end
