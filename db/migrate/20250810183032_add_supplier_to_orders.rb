class AddSupplierToOrders < ActiveRecord::Migration[8.0]
  def change
    # Колонка supplier_id уже существует, добавляем только индекс
    unless index_exists?(:orders, [:supplier_id, :status], name: 'index_orders_on_supplier_id_and_status')
      add_index :orders, [:supplier_id, :status], name: 'index_orders_on_supplier_id_and_status'
    end
  end
end
