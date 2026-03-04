# Migration: create loyalty accounts for client loyalty program
class CreateLoyaltyAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :loyalty_accounts do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.integer :points, null: false, default: 0
      t.string :level, null: false, default: 'bronze'

      t.timestamps
    end

    add_index :loyalty_accounts, :level
    add_index :loyalty_accounts, :points
  end
end
