class RemoveAutoConfirmationFromServicePoints < ActiveRecord::Migration[8.0]
  def change
    remove_column :service_points, :auto_confirmation, :boolean
  end
end
