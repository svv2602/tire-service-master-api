class UpdateSupplierTireProductsWithNormalization < ActiveRecord::Migration[8.0]
  def change
    # Добавляем связи с справочными таблицами
    add_reference :supplier_tire_products, :tire_brand, foreign_key: true, comment: 'Нормализованный бренд'
    add_reference :supplier_tire_products, :tire_model, foreign_key: true, comment: 'Нормализованная модель'
    add_reference :supplier_tire_products, :country, foreign_key: true, comment: 'Нормализованная страна производства'
    
    # Переименовываем существующие поля для сохранения оригинальных данных
    rename_column :supplier_tire_products, :brand, :original_brand
    rename_column :supplier_tire_products, :model, :original_model  
    rename_column :supplier_tire_products, :country, :original_country
    
    # Добавляем поле для парсинга года из year_week
    add_column :supplier_tire_products, :production_year, :integer, comment: 'Год производства (извлеченный из year_week)'
    
    # Добавляем поле для кэширования рейтинга оптимальности
    add_column :supplier_tire_products, :optimality_score, :decimal, precision: 5, scale: 2, comment: 'Рассчитанный рейтинг оптимальности'
    
    # Обновляем индексы для новой структуры
    remove_index :supplier_tire_products, name: 'idx_supplier_tire_products_search'
    remove_index :supplier_tire_products, :brand_normalized
    
    # Новые индексы для нормализованных данных
    add_index :supplier_tire_products, [:tire_brand_id, :width, :height, :diameter, :season, :in_stock], 
              name: 'idx_supplier_products_normalized_search'
    add_index :supplier_tire_products, :optimality_score
    add_index :supplier_tire_products, :production_year
    add_index :supplier_tire_products, [:tire_brand_id, :tire_model_id]
  end
end