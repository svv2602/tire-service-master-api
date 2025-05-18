class RemoveUniqueNameConstraintFromServicePoints < ActiveRecord::Migration[8.0]
  def up
    # Добавляем проверку наличия индекса перед его удалением
    if index_exists?(:service_points, :name)
      remove_index :service_points, :name
    end

    # Проверяем наличие уникального индекса с другим именем
    indexes = connection.indexes(:service_points)
    unique_name_indexes = indexes.select { |i| i.columns.include?('name') && i.unique }
    
    unique_name_indexes.each do |index|
      remove_index :service_points, name: index.name
    end
  end

  def down
    # Восстановление индекса можно реализовать при необходимости
    # add_index :service_points, :name, unique: true
    # Но в данном случае мы не восстанавливаем уникальный индекс
  end
end
