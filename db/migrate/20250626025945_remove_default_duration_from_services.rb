class RemoveDefaultDurationFromServices < ActiveRecord::Migration[8.0]
  def change
    remove_column :services, :default_duration, :integer
  end
end
