class CreatePageContents < ActiveRecord::Migration[8.0]
  def change
    create_table :page_contents do |t|
      t.string :section
      t.string :content_type
      t.text :title
      t.text :content
      t.text :image_url
      t.text :settings
      t.integer :position
      t.boolean :active

      t.timestamps
    end
  end
end
