class AddCarTypeToClientCars < ActiveRecord::Migration[8.0]
  def change
    add_reference :client_cars, :car_type, null: true, foreign_key: true
    
    # Устанавливаем тип Sedan для существующих автомобилей
    reversible do |dir|
      dir.up do
        # Находим ID для типа "Sedan"
        execute <<-SQL
          UPDATE client_cars 
          SET car_type_id = (SELECT id FROM car_types WHERE name = 'Sedan' LIMIT 1)
          WHERE car_type_id IS NULL;
        SQL
      end
    end
  end
end
