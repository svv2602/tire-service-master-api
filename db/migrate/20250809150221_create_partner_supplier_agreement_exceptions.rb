class CreatePartnerSupplierAgreementExceptions < ActiveRecord::Migration[8.0]
  def change
    create_table :partner_supplier_agreement_exceptions do |t|
      t.references :partner_supplier_agreement, null: false, foreign_key: true, index: { name: 'idx_exceptions_on_agreement_id' }
      
      # Условия применения исключения
      t.integer :tire_brand_id, null: true, comment: 'ID бренда шин (NULL = все бренды)'
      t.string :tire_diameter, null: true, limit: 10, comment: 'Диаметр шин (NULL = все диаметры)'
      
      # Тип и значение исключения
      t.string :exception_type, null: false, default: 'fixed_amount', 
               comment: 'Тип: fixed_amount, percentage'
      t.decimal :exception_amount, precision: 10, scale: 2, null: true,
                comment: 'Фиксированная сумма исключения'
      t.decimal :exception_percentage, precision: 5, scale: 2, null: true,
                comment: 'Процент исключения'
      
      # Область применения
      t.string :application_scope, null: false, default: 'per_order',
               comment: 'Область применения: per_order (весь заказ), per_item (каждая единица)'
      
      # Приоритет и активность
      t.integer :priority, null: false, default: 0,
                comment: 'Приоритет применения (больше = выше приоритет)'
      t.boolean :active, null: false, default: true,
                comment: 'Активно ли исключение'
      
      # Описание
      t.text :description, null: true, comment: 'Описание исключения'

      t.timestamps
    end
    
    # Индексы для производительности
    add_index :partner_supplier_agreement_exceptions, :tire_brand_id
    add_index :partner_supplier_agreement_exceptions, :tire_diameter
    add_index :partner_supplier_agreement_exceptions, :active
    add_index :partner_supplier_agreement_exceptions, :priority
    add_index :partner_supplier_agreement_exceptions, [:tire_brand_id, :tire_diameter], 
              name: 'idx_exceptions_on_brand_diameter'
    
    # Проверочные ограничения
    add_check_constraint :partner_supplier_agreement_exceptions, 
                        "exception_type IN ('fixed_amount', 'percentage')", 
                        name: 'check_exception_type_valid'
    
    add_check_constraint :partner_supplier_agreement_exceptions, 
                        "application_scope IN ('per_order', 'per_item')", 
                        name: 'check_application_scope_valid'
    
    # Логическое ограничение: должно быть указано либо сумма, либо процент
    add_check_constraint :partner_supplier_agreement_exceptions, 
                        "(exception_type = 'fixed_amount' AND exception_amount IS NOT NULL AND exception_percentage IS NULL) OR " +
                        "(exception_type = 'percentage' AND exception_percentage IS NOT NULL AND exception_amount IS NULL)", 
                        name: 'check_exception_value_consistency'
  end
end
