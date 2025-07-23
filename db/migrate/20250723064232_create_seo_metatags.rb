class CreateSeoMetatags < ActiveRecord::Migration[8.0]
  def change
    create_table :seo_metatags do |t|
      t.string :page_type, null: false
      t.text :title, null: false
      t.text :description, null: false
      t.text :keywords
      t.string :image_url
      t.string :canonical_url
      t.boolean :no_index, default: false, null: false
      t.string :language, default: 'uk', null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    # Индексы для быстрого поиска
    add_index :seo_metatags, :page_type
    add_index :seo_metatags, :language
    add_index :seo_metatags, :active
    add_index :seo_metatags, [:page_type, :language], unique: true, name: 'index_seo_metatags_on_page_type_and_language'
  end
end
