class AddLanguageSupportToPageContents < ActiveRecord::Migration[8.0]
  def change
    add_column :page_contents, :language, :string, default: 'uk', null: false
    add_index :page_contents, :language
    add_index :page_contents, [:section, :language]
    add_index :page_contents, [:content_type, :language]
  end
end
