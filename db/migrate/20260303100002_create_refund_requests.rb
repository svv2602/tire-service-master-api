class CreateRefundRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :refund_requests do |t|
      t.references :payment, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true, comment: 'User who requested the refund'
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :reason, null: false
      t.string :reason_category, null: false
      t.boolean :is_full_refund, default: false, null: false
      t.string :status, default: 'pending', null: false
      t.datetime :processed_at

      t.timestamps
    end

    add_index :refund_requests, :status
  end
end
