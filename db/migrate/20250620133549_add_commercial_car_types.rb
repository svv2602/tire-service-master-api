class AddCommercialCarTypes < ActiveRecord::Migration[8.0]
  def change
    # Добавляем дополнительные типы автомобилей для коммерческого транспорта
    
    # Легкий коммерческий транспорт (Газель, Форд Транзит и т.д.)
    execute <<-SQL
      INSERT INTO car_types (name, description, is_active, created_at, updated_at) VALUES
      ('Легкий коммерческий транспорт', 'Коммерческие автомобили для перевозки грузов и пассажиров (Газель, Форд Транзит, Ивеко Дейли)', true, NOW(), NOW());
    SQL
    
    # Грузовик малой грузоподъемности  
    execute <<-SQL
      INSERT INTO car_types (name, description, is_active, created_at, updated_at) VALUES
      ('Малотоннажный грузовик', 'Грузовые автомобили грузоподъемностью до 3,5 тонн', true, NOW(), NOW());
    SQL
    
    # Микроавтобус
    execute <<-SQL
      INSERT INTO car_types (name, description, is_active, created_at, updated_at) VALUES
      ('Микроавтобус', 'Автобус малой вместимости для перевозки до 20 пассажиров', true, NOW(), NOW());
    SQL
  end
end
