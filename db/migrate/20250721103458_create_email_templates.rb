class CreateEmailTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :email_templates do |t|
      t.string :name
      t.string :subject
      t.text :body
      t.string :template_type
      t.string :language
      t.boolean :is_active
      t.text :variables
      t.text :description

      t.timestamps
    end
  end
end
