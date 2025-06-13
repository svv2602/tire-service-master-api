class CreateOperators < ActiveRecord::Migration[8.0]
  def change
    create_table :operators do |t|
      t.references :user, null: false, foreign_key: true
      t.string :position
      t.integer :access_level
      t.boolean :is_active

      t.timestamps
    end
  end
end
