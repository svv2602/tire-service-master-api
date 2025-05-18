class FixServicePointNameUniqueness < ActiveRecord::Migration[8.0]
  def change
    # Удаляем композитный индекс partner_id + name, если он существует
    if index_exists?(:service_points, [:partner_id, :name], name: 'idx_unique_service_point_name_per_partner')
      remove_index :service_points, name: 'idx_unique_service_point_name_per_partner'
    end
    
    # Проверяем все индексы, которые могут содержать name
    indexes = connection.indexes(:service_points)
    name_indexes = indexes.select { |i| i.columns.include?('name') }
    
    name_indexes.each do |index|
      remove_index :service_points, name: index.name
    end
    
    # Не добавляем никаких новых индексов уникальности
  end
end
