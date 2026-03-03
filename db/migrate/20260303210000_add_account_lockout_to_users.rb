# frozen_string_literal: true

class AddAccountLockoutToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :failed_login_attempts, :integer, default: 0, null: false
    add_column :users, :locked_until, :datetime, null: true
  end
end
