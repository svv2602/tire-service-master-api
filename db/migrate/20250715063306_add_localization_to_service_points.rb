class AddLocalizationToServicePoints < ActiveRecord::Migration[8.0]
  def up
    # Добавляем новые колонки
    add_column :service_points, :name_ru, :string
    add_column :service_points, :name_uk, :string
    add_column :service_points, :description_ru, :text
    add_column :service_points, :description_uk, :text
    add_column :service_points, :address_ru, :string
    add_column :service_points, :address_uk, :string
    
    # Мигрируем существующие данные
    # Копируем данные из оригинальных полей в русские поля
    execute <<-SQL
      UPDATE service_points 
      SET name_ru = name, 
          description_ru = COALESCE(description, ''),
          address_ru = address
      WHERE name_ru IS NULL OR description_ru IS NULL OR address_ru IS NULL;
    SQL
    
    # Копируем данные из русских полей в украинские (как fallback)
    execute <<-SQL
      UPDATE service_points 
      SET name_uk = name_ru,
          description_uk = description_ru,
          address_uk = address_ru
      WHERE name_uk IS NULL OR description_uk IS NULL OR address_uk IS NULL;
    SQL
    
    # Добавляем индексы для производительности
    add_index :service_points, :name_ru
    add_index :service_points, :name_uk
    
    # Добавляем NOT NULL constraints после миграции данных
    change_column_null :service_points, :name_ru, false
    change_column_null :service_points, :name_uk, false
    change_column_null :service_points, :description_ru, false
    change_column_null :service_points, :description_uk, false
    change_column_null :service_points, :address_ru, false
    change_column_null :service_points, :address_uk, false
  end
  
  def down
    # Удаляем индексы
    remove_index :service_points, :name_ru if index_exists?(:service_points, :name_ru)
    remove_index :service_points, :name_uk if index_exists?(:service_points, :name_uk)
    
    # Удаляем колонки
    remove_column :service_points, :name_ru
    remove_column :service_points, :name_uk
    remove_column :service_points, :description_ru
    remove_column :service_points, :description_uk
    remove_column :service_points, :address_ru
    remove_column :service_points, :address_uk
  end
end
