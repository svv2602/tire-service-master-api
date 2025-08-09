class CreatePartnerSupplierAgreementExceptionBrands < ActiveRecord::Migration[8.0]
  def change
    create_table :partner_supplier_agreement_exception_brands do |t|
      t.references :partner_supplier_agreement_exception, null: false, foreign_key: true, 
                   index: { name: 'idx_exception_brands_on_exception_id' }
      t.integer :tire_brand_id, null: false, comment: 'ID бренда шин'

      t.timestamps
    end
    
    # Индексы для оптимизации запросов
    add_index :partner_supplier_agreement_exception_brands, :tire_brand_id
    add_index :partner_supplier_agreement_exception_brands, 
              [:partner_supplier_agreement_exception_id, :tire_brand_id], 
              unique: true, 
              name: 'idx_exception_brands_unique'
  end
end
