class CreatePayments < ActiveRecord::Migration[8.0]
  def change
    create_table :payments do |t|
      t.string :payment_id, null: false, comment: 'External payment provider ID'
      t.string :provider, default: 'liqpay', null: false, comment: 'Payment provider name'
      t.string :payment_type, null: false, comment: 'booking or order'
      t.bigint :entity_id, null: false, comment: 'ID of related booking or order'
      t.references :user, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :currency, default: 'UAH', null: false
      t.string :status, default: 'pending', null: false
      t.string :description
      t.datetime :paid_at
      t.datetime :refunded_at
      t.decimal :refund_amount, precision: 10, scale: 2
      t.string :receipt_url
      t.string :provider_payment_id, comment: 'Provider internal transaction ID'

      t.timestamps
    end

    add_index :payments, :payment_id, unique: true
    add_index :payments, :status
    add_index :payments, [:payment_type, :entity_id]
  end
end
