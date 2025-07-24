class CreateServicePointCategorySettings < ActiveRecord::Migration[8.0]
  def change
    create_table :service_point_category_settings do |t|
      t.references :service_point, null: false, foreign_key: true
      t.references :service_category, null: false, foreign_key: true
      t.boolean :auto_confirmation, default: false, null: false, comment: 'Автоматическое подтверждение бронирований для данной категории услуг'

      t.timestamps
    end
    
    # Уникальный индекс - одна настройка на комбинацию точки и категории
    add_index :service_point_category_settings, [:service_point_id, :service_category_id], 
              unique: true, 
              name: 'index_sp_category_settings_unique'
              
    # Индекс для быстрого поиска настроек с автоподтверждением
    add_index :service_point_category_settings, :auto_confirmation
  end
end
