class CreatePartnerSupplierAgreementExceptionDiameters < ActiveRecord::Migration[8.0]
  def change
    create_table :partner_supplier_agreement_exception_diameters do |t|
      t.references :partner_supplier_agreement_exception, null: false, foreign_key: true,
                   index: { name: 'idx_exception_diameters_on_exception_id' }
      t.string :tire_diameter, null: false, limit: 10, comment: 'Диаметр шин (например, "15", "16")'

      t.timestamps
    end
    
    # Индексы для оптимизации запросов
    add_index :partner_supplier_agreement_exception_diameters, :tire_diameter
    add_index :partner_supplier_agreement_exception_diameters, 
              [:partner_supplier_agreement_exception_id, :tire_diameter], 
              unique: true, 
              name: 'idx_exception_diameters_unique'
  end
end
