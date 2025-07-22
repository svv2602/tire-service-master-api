class AddChannelTypeToEmailTemplates < ActiveRecord::Migration[8.0]
  def up
    # Добавляем колонку с дефолтным значением 'email'
    add_column :email_templates, :channel_type, :string, default: 'email', null: false
    add_index :email_templates, :channel_type
    
    # Обновляем существующие записи (все текущие шаблоны - email)
    execute "UPDATE email_templates SET channel_type = 'email' WHERE channel_type IS NULL"
    
    # Добавляем ограничение на возможные значения
    execute <<-SQL
      ALTER TABLE email_templates 
      ADD CONSTRAINT check_channel_type 
      CHECK (channel_type IN ('email', 'telegram', 'push'))
    SQL
    
    # Обновляем уникальный индекс для учета channel_type
    remove_index :email_templates, [:template_type, :language] if index_exists?(:email_templates, [:template_type, :language])
    add_index :email_templates, [:template_type, :language, :channel_type], unique: true, name: 'index_email_templates_on_type_language_channel'
  end

  def down
    remove_constraint :email_templates, :check_channel_type if constraint_exists?(:email_templates, :check_channel_type)
    remove_index :email_templates, name: 'index_email_templates_on_type_language_channel' if index_exists?(:email_templates, name: 'index_email_templates_on_type_language_channel')
    remove_index :email_templates, :channel_type if index_exists?(:email_templates, :channel_type)
    remove_column :email_templates, :channel_type
    
    # Восстанавливаем старый уникальный индекс
    add_index :email_templates, [:template_type, :language], unique: true unless index_exists?(:email_templates, [:template_type, :language])
  end

  private

  def constraint_exists?(table_name, constraint_name)
    connection.execute(<<-SQL).any?
      SELECT 1 FROM information_schema.table_constraints 
      WHERE table_name = '#{table_name}' AND constraint_name = '#{constraint_name}'
    SQL
  end
end
