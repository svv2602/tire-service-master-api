class AddPriceFieldsToServicePointServices < ActiveRecord::Migration[8.0]
  def change
    add_column :service_point_services, :price, :decimal, precision: 10, scale: 2, null: false, default: 0
    add_column :service_point_services, :duration, :integer, null: false, default: 60 # минуты
    add_column :service_point_services, :is_available, :boolean, null: false, default: true
  end
end
