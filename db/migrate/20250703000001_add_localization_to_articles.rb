class AddLocalizationToArticles < ActiveRecord::Migration[8.0]
  def change
    # Добавляем украинские поля для локализации
    add_column :articles, :title_uk, :string, limit: 255
    add_column :articles, :content_uk, :text
    add_column :articles, :excerpt_uk, :text, limit: 500
    add_column :articles, :meta_title_uk, :string, limit: 60
    add_column :articles, :meta_description_uk, :text, limit: 160
    
    # Добавляем индексы для поиска
    add_index :articles, :title_uk
    add_index :articles, [:title, :title_uk], name: 'index_articles_on_localized_titles'
    
    # Переименовываем существующие поля для ясности (опционально)
    # Можно оставить как есть, но добавить комментарий что это русские поля
    
    # Добавляем комментарии для ясности
    change_column_comment :articles, :title, 'Заголовок статьи на русском языке'
    change_column_comment :articles, :content, 'Содержимое статьи на русском языке'
    change_column_comment :articles, :excerpt, 'Краткое описание статьи на русском языке'
    change_column_comment :articles, :meta_title, 'SEO заголовок на русском языке'
    change_column_comment :articles, :meta_description, 'SEO описание на русском языке'
    
    change_column_comment :articles, :title_uk, 'Заголовок статьи на украинском языке'
    change_column_comment :articles, :content_uk, 'Содержимое статьи на украинском языке'
    change_column_comment :articles, :excerpt_uk, 'Краткое описание статьи на украинском языке'
    change_column_comment :articles, :meta_title_uk, 'SEO заголовок на украинском языке'
    change_column_comment :articles, :meta_description_uk, 'SEO описание на украинском языке'
  end
end 