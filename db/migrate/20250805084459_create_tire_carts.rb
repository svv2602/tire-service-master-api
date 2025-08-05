class CreateTireCarts < ActiveRecord::Migration[8.0]
  def change
    create_table :tire_carts do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }

      t.timestamps
    end
  end
end
