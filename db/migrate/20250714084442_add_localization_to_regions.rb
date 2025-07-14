class AddLocalizationToRegions < ActiveRecord::Migration[8.0]
  def change
    # Добавляем только недостающее поле name_ru (name_uk уже существует)
    add_column :regions, :name_ru, :string
    
    # Добавляем индексы для быстрого поиска по локализованным названиям
    add_index :regions, :name_ru
    
    # Заполняем существующие записи русскими названиями как базовые
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE regions SET name_ru = name WHERE name_ru IS NULL;
        SQL
      end
    end
  end
end
