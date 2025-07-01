class AddPartnerIdToOperators < ActiveRecord::Migration[8.0]
  def change
    add_column :operators, :partner_id, :bigint
    add_index :operators, :partner_id
  end
end
