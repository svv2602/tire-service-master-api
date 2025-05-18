class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email, null: false, index: { unique: true }
      t.string :phone, index: { unique: true }
      t.string :password_digest, null: false
      t.string :first_name
      t.string :last_name
      t.string :middle_name
      t.references :role, null: false, foreign_key: { to_table: :user_roles }
      t.datetime :last_login
      t.boolean :is_active, default: true
      t.boolean :email_verified, default: false
      t.boolean :phone_verified, default: false
      t.timestamps
    end
  end
end
