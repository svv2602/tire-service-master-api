# Migration: create loyalty transactions to track points history
class CreateLoyaltyTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :loyalty_transactions do |t|
      t.references :loyalty_account, null: false, foreign_key: true
      t.integer :points, null: false
      t.string :reason, null: false
      t.references :booking, null: true, foreign_key: true
      t.references :tire_order, null: true, foreign_key: true
      t.references :review, null: true, foreign_key: true
      t.references :referral_user, null: true, foreign_key: { to_table: :users }
      t.text :description

      t.timestamps
    end

    add_index :loyalty_transactions, :reason
    add_index :loyalty_transactions, :created_at
  end
end
