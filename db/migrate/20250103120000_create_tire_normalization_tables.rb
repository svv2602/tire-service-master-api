class CreateTireNormalizationTables < ActiveRecord::Migration[8.0]
  def change
    # Справочник стран производства
    create_table :countries do |t|
      t.string :name, null: false, limit: 100, comment: 'Каноничное название страны'
      t.string :normalized_name, null: false, limit: 100, comment: 'Нормализованное название для поиска'
      t.string :iso_code, limit: 3, comment: 'ISO код страны (DE, CN, JP)'
      t.integer :rating_score, default: 5, comment: 'Рейтинг качества производства (1-10)'
      t.text :aliases, array: true, default: [], comment: 'Альтернативные названия'
      t.boolean :is_active, default: true, comment: 'Активность справочника'
      
      t.timestamps
    end
    
    # Справочник брендов шин
    create_table :tire_brands do |t|
      t.string :name, null: false, limit: 100, comment: 'Каноничное название бренда'
      t.string :normalized_name, null: false, limit: 100, comment: 'Нормализованное название для поиска'
      t.integer :rating_score, default: 5, comment: 'Рейтинг бренда (1-10)'
      t.text :aliases, array: true, default: [], comment: 'Альтернативные названия и алиасы'
      t.references :country, foreign_key: true, comment: 'Страна происхождения бренда'
      t.boolean :is_premium, default: false, comment: 'Премиум сегмент'
      t.boolean :is_active, default: true, comment: 'Активность справочника'
      
      t.timestamps
    end
    
    # Справочник моделей шин
    create_table :tire_models do |t|
      t.references :tire_brand, null: false, foreign_key: true, comment: 'Бренд шины'
      t.string :name, null: false, limit: 255, comment: 'Каноничное название модели'
      t.string :normalized_name, null: false, limit: 255, comment: 'Нормализованное название для поиска'
      t.integer :rating_score, default: 5, comment: 'Рейтинг модели (1-10)'
      t.text :aliases, array: true, default: [], comment: 'Альтернативные названия модели'
      t.string :season_type, limit: 20, comment: 'Тип сезонности (summer, winter, all_season)'
      t.boolean :is_active, default: true, comment: 'Активность справочника'
      
      t.timestamps
    end

    # Индексы для быстрого поиска
    add_index :countries, :normalized_name, unique: true
    add_index :countries, :iso_code
    add_index :countries, :rating_score
    add_index :countries, :aliases, using: :gin
    
    add_index :tire_brands, :normalized_name, unique: true
    add_index :tire_brands, :rating_score
    add_index :tire_brands, :is_premium
    add_index :tire_brands, :aliases, using: :gin
    add_index :tire_brands, [:country_id, :is_premium]
    
    add_index :tire_models, [:tire_brand_id, :normalized_name], unique: true
    add_index :tire_models, :rating_score
    add_index :tire_models, :season_type
    add_index :tire_models, :aliases, using: :gin
    add_index :tire_models, [:tire_brand_id, :season_type]
  end
end