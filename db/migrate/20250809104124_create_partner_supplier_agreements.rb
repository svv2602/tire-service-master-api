class CreatePartnerSupplierAgreements < ActiveRecord::Migration[8.0]
  def change
    create_table :partner_supplier_agreements do |t|
      t.references :partner, null: false, foreign_key: true
      t.references :supplier, null: false, foreign_key: true
      t.date :start_date, null: false
      t.date :end_date
      t.string :commission_type, null: false, default: 'custom'
      t.boolean :active, null: false, default: true
      t.text :description

      t.timestamps
    end

    # Индексы для оптимизации запросов
    add_index :partner_supplier_agreements, [:partner_id, :supplier_id], 
              name: 'index_agreements_on_partner_supplier'
    add_index :partner_supplier_agreements, :active
    add_index :partner_supplier_agreements, :start_date
  end
end
