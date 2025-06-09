class AddLicensePlateToClientCars < ActiveRecord::Migration[8.0]
  def change
    add_column :client_cars, :license_plate, :string
  end
end
