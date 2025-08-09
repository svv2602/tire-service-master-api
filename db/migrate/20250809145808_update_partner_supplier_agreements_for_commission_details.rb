class UpdatePartnerSupplierAgreementsForCommissionDetails < ActiveRecord::Migration[8.0]
  def change
    # Добавляем поля для детализации общих условий комиссии
    add_column :partner_supplier_agreements, :commission_amount, :decimal, 
               precision: 10, scale: 2, null: true,
               comment: 'Фиксированная сумма комиссии (если применимо)'
    
    add_column :partner_supplier_agreements, :commission_percentage, :decimal, 
               precision: 5, scale: 2, null: true,
               comment: 'Процент комиссии (если применимо)'
    
    add_column :partner_supplier_agreements, :commission_unit, :string, 
               null: true, default: 'per_order',
               comment: 'За что начисляется: per_order, per_item'
    
    # Проверочные ограничения
    add_check_constraint :partner_supplier_agreements, 
                        "commission_unit IN ('per_order', 'per_item')", 
                        name: 'check_commission_unit_valid'
    
    # Обновляем значения commission_type
    reversible do |dir|
      dir.up do
        # Меняем значения на более понятные
        execute <<-SQL
          UPDATE partner_supplier_agreements 
          SET commission_type = CASE commission_type
            WHEN 'fixed_amount' THEN 'fixed_amount'
            WHEN 'fixed_percentage' THEN 'percentage'
            WHEN 'custom' THEN 'custom'
            ELSE 'custom'
          END;
        SQL
        
        # Обновляем проверочное ограничение
        remove_check_constraint :partner_supplier_agreements, name: 'check_commission_type_valid', if_exists: true
        add_check_constraint :partner_supplier_agreements, 
                            "commission_type IN ('fixed_amount', 'percentage', 'custom')", 
                            name: 'check_commission_type_valid'
      end
      
      dir.down do
        # Возвращаем старые значения при откате
        execute <<-SQL
          UPDATE partner_supplier_agreements 
          SET commission_type = CASE commission_type
            WHEN 'fixed_amount' THEN 'fixed_amount'
            WHEN 'percentage' THEN 'fixed_percentage'
            WHEN 'custom' THEN 'custom'
            ELSE 'custom'
          END;
        SQL
      end
    end
  end
end
