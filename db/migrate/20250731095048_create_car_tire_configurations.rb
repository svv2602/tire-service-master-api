class CreateCarTireConfigurations < ActiveRecord::Migration[8.0]
  def change
    create_table :car_tire_configurations do |t|
      t.references :brand, null: false, foreign_key: { to_table: :car_brands }
      t.references :model, null: false, foreign_key: { to_table: :car_models }
      t.integer :year_from
      t.integer :year_to
      t.jsonb :tire_sizes
      t.jsonb :search_aliases
      t.text :search_tokens
      t.string :data_version, default: '2025.1'
      t.string :source_file
      t.datetime :last_updated
      t.boolean :is_deprecated, default: false
      t.boolean :is_active, default: true

      t.timestamps
    end
    
    # Индексы для оптимизации поиска
    add_index :car_tire_configurations, [:brand_id, :model_id]
    add_index :car_tire_configurations, :data_version
    add_index :car_tire_configurations, :is_active
    add_index :car_tire_configurations, :is_deprecated
    
    # GIN индексы для JSON полей (PostgreSQL)
    if ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
      execute "CREATE INDEX index_car_tire_configurations_on_tire_sizes ON car_tire_configurations USING gin (tire_sizes jsonb_path_ops)"
      execute "CREATE INDEX index_car_tire_configurations_on_search_aliases ON car_tire_configurations USING gin (search_aliases jsonb_path_ops)"
    end
    
    # Полнотекстовый поиск для search_tokens
    if ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
      execute <<-SQL
        CREATE INDEX index_car_tire_configurations_on_search_tokens_fulltext 
        ON car_tire_configurations 
        USING gin(to_tsvector('russian', search_tokens));
      SQL
    else
      add_index :car_tire_configurations, :search_tokens
    end
  end
end
