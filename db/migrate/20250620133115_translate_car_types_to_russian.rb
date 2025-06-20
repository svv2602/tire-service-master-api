class TranslateCarTypesToRussian < ActiveRecord::Migration[8.0]
  def change
    # Переводим названия и описания типов автомобилей на русский язык
    
    # Sedan -> Седан
    execute <<-SQL
      UPDATE car_types 
      SET name = 'Седан', 
          description = 'Стандартный легковой автомобиль с отдельным багажником'
      WHERE name = 'Sedan';
    SQL
    
    # Hatchback -> Хэтчбек
    execute <<-SQL
      UPDATE car_types 
      SET name = 'Хэтчбек', 
          description = 'Автомобиль с задней дверью, открывающейся вверх, багажник интегрирован в пассажирский салон'
      WHERE name = 'Hatchback';
    SQL
    
    # SUV -> Внедорожник
    execute <<-SQL
      UPDATE car_types 
      SET name = 'Внедорожник', 
          description = 'Спортивно-утилитарный автомобиль, сочетающий характеристики легкового автомобиля и внедорожника'
      WHERE name = 'SUV';
    SQL
    
    # Crossover -> Кроссовер
    execute <<-SQL
      UPDATE car_types 
      SET name = 'Кроссовер', 
          description = 'Автомобиль с элементами дизайна внедорожника, но построенный на платформе легкового автомобиля'
      WHERE name = 'Crossover';
    SQL
    
    # Pickup -> Пикап
    execute <<-SQL
      UPDATE car_types 
      SET name = 'Пикап', 
          description = 'Легкий грузовик с открытой грузовой площадкой сзади'
      WHERE name = 'Pickup';
    SQL
    
    # Minivan -> Минивэн
    execute <<-SQL
      UPDATE car_types 
      SET name = 'Минивэн', 
          description = 'Микроавтобус для пассажирских перевозок с двумя или тремя рядами сидений'
      WHERE name = 'Minivan';
    SQL
    
    # Coupe -> Купе
    execute <<-SQL
      UPDATE car_types 
      SET name = 'Купе', 
          description = 'Двухдверный автомобиль с фиксированной крышей и покатой задней частью'
      WHERE name = 'Coupe';
    SQL
    
    # Convertible -> Кабриолет
    execute <<-SQL
      UPDATE car_types 
      SET name = 'Кабриолет', 
          description = 'Автомобиль со складывающейся или съемной крышей'
      WHERE name = 'Convertible';
    SQL
    
    # Wagon -> Универсал
    execute <<-SQL
      UPDATE car_types 
      SET name = 'Универсал', 
          description = 'Автомобиль с расширенной грузовой зоной, похожий на хэтчбек, но с большим грузовым пространством'
      WHERE name = 'Wagon';
    SQL
    
    # Van -> Фургон
    execute <<-SQL
      UPDATE car_types 
      SET name = 'Фургон', 
          description = 'Тип дорожного транспортного средства для перевозки товаров или людей'
      WHERE name = 'Van';
    SQL
  end
end
