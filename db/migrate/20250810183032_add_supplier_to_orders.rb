class AddSupplierToOrders < ActiveRecord::Migration[8.0]
  def change
    add_reference :orders, :supplier, null: true, foreign_key: true, comment: 'Поставщик, от которого поступил заказ (опционально)'
    add_index :orders, [:supplier_id, :status], name: 'index_orders_on_supplier_id_and_status'
  end
end
