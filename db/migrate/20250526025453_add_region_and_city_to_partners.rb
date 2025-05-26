class AddRegionAndCityToPartners < ActiveRecord::Migration[8.0]
  def change
    add_reference :partners, :region, null: true, foreign_key: true
    add_reference :partners, :city, null: true, foreign_key: true
  end
end
