class AddOrderTypesToPartnerSupplierAgreements < ActiveRecord::Migration[8.0]
  def change
    add_column :partner_supplier_agreements, :order_types, :string, 
               null: false, 
               default: 'both',
               comment: 'Типы заказов: cart_orders, pickup_orders, both'
    
    # Добавляем проверочное ограничение
    add_check_constraint :partner_supplier_agreements, 
                        "order_types IN ('cart_orders', 'pickup_orders', 'both')", 
                        name: 'check_order_types_valid'
    
    # Добавляем индекс для производительности
    add_index :partner_supplier_agreements, :order_types
  end
end
