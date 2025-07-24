class ModifyEmailTemplatesUniqueIndexForNewsletter < ActiveRecord::Migration[8.0]
  def up
    # Удаляем старый уникальный индекс
    remove_index :email_templates, name: 'index_email_templates_on_type_language_channel' if index_exists?(:email_templates, [:template_type, :language, :channel_type], name: 'index_email_templates_on_type_language_channel')
    
    # Создаем частичный уникальный индекс, исключающий newsletter шаблоны
    # Это позволит иметь несколько newsletter шаблонов для каждого языка и канала
    execute <<-SQL
      CREATE UNIQUE INDEX index_email_templates_on_type_language_channel_excl_newsletter 
      ON email_templates (template_type, language, channel_type) 
      WHERE template_type != 'newsletter'
    SQL
    
    # Добавляем обычный индекс для newsletter шаблонов (без уникальности)
    add_index :email_templates, [:template_type, :language, :channel_type], 
              where: "template_type = 'newsletter'", 
              name: 'index_email_templates_newsletter_only'
  end

  def down
    # Удаляем новые индексы
    remove_index :email_templates, name: 'index_email_templates_on_type_language_channel_excl_newsletter' if index_exists?(:email_templates, [:template_type, :language, :channel_type], name: 'index_email_templates_on_type_language_channel_excl_newsletter')
    remove_index :email_templates, name: 'index_email_templates_newsletter_only' if index_exists?(:email_templates, [:template_type, :language, :channel_type], name: 'index_email_templates_newsletter_only')
    
    # Восстанавливаем старый уникальный индекс
    add_index :email_templates, [:template_type, :language, :channel_type], unique: true, name: 'index_email_templates_on_type_language_channel'
  end
end
