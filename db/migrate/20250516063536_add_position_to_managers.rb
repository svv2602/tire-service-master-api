class AddPositionToManagers < ActiveRecord::Migration[8.0]
  def change
    add_column :managers, :position, :string
  end
end
