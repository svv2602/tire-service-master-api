class CreateArticles < ActiveRecord::Migration[8.0]
  def change
    create_table :articles do |t|
      # Основные поля
      t.string :title, null: false, limit: 255
      t.text :content, null: false
      t.text :excerpt, limit: 500
      
      # Категоризация и статус
      t.string :category, null: false, limit: 50, default: 'tips'
      t.string :status, null: false, limit: 20, default: 'draft'
      t.boolean :featured, default: false
      
      # Метаданные для SEO
      t.string :meta_title, limit: 60
      t.text :meta_description, limit: 160
      t.string :slug, limit: 255
      
      # Автор и временные метки
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.datetime :published_at
      
      # Статистика
      t.integer :views_count, default: 0
      t.integer :reading_time, default: 1 # в минутах
      
      # Изображения
      t.string :featured_image_url
      t.json :gallery_images # массив URL изображений
      
      # Дополнительные настройки
      t.boolean :allow_comments, default: true
      t.json :tags # массив тегов
      
      t.timestamps
    end

    # Индексы для производительности
    add_index :articles, :status
    add_index :articles, :category
    add_index :articles, :featured
    add_index :articles, :published_at
    add_index :articles, :slug, unique: true
    add_index :articles, [:status, :published_at], name: 'index_articles_on_status_and_published_at'
    add_index :articles, [:category, :status], name: 'index_articles_on_category_and_status'
  end
end