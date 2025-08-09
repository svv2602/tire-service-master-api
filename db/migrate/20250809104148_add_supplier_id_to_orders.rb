class AddSupplierIdToOrders < ActiveRecord::Migration[8.0]
  def change
    # Добавляем supplier_id как nullable сначала, потом заполним данные
    # add_reference уже создает индекс автоматически
    add_reference :orders, :supplier, null: true, foreign_key: true
  end
end
