class AddProfileFieldsToSuppliers < ActiveRecord::Migration[8.0]
  def change
    add_column :suppliers, :email, :string
    add_column :suppliers, :phone, :string
    add_column :suppliers, :description, :text
    add_column :suppliers, :website, :string
    add_column :suppliers, :contact_person, :string
    add_column :suppliers, :address, :string
    add_column :suppliers, :telegram_chat_id, :string
  end
end
