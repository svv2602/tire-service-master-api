class CreateEmailTemplateCustomVariables < ActiveRecord::Migration[8.0]
  def change
    create_table :email_template_custom_variables do |t|
      t.references :email_template, null: false, foreign_key: true
      t.references :custom_variable, null: false, foreign_key: true

      t.timestamps
    end

    # Уникальный индекс для предотвращения дублирования связей
    add_index :email_template_custom_variables, 
              [:email_template_id, :custom_variable_id], 
              unique: true,
              name: 'index_template_custom_vars_unique'
  end
end
