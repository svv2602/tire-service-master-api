class AddUkrainianTranslationsToCarTypes < ActiveRecord::Migration[8.0]
  def change
    add_column :car_types, :name_uk, :string
    add_column :car_types, :description_uk, :text
    
    # Добавляем украинские переводы для существующих типов автомобилей
    reversible do |dir|
      dir.up do
        # Седан
        execute <<-SQL
          UPDATE car_types 
          SET name_uk = 'Седан', 
              description_uk = 'Стандартний легковий автомобіль з окремим багажником'
          WHERE name = 'Седан';
        SQL
        
        # Хэтчбек
        execute <<-SQL
          UPDATE car_types 
          SET name_uk = 'Хетчбек', 
              description_uk = 'Автомобіль із задніми дверима, що відкриваються вгору, багажник інтегрований у пасажирський салон'
          WHERE name = 'Хэтчбек';
        SQL
        
        # Внедорожник
        execute <<-SQL
          UPDATE car_types 
          SET name_uk = 'Позашляховик', 
              description_uk = 'Спортивно-утилітарний автомобіль, що поєднує характеристики легкового автомобіля та позашляховика'
          WHERE name = 'Внедорожник';
        SQL
        
        # Кроссовер
        execute <<-SQL
          UPDATE car_types 
          SET name_uk = 'Кросовер', 
              description_uk = 'Автомобіль з елементами дизайну позашляховика, але побудований на платформі легкового автомобіля'
          WHERE name = 'Кроссовер';
        SQL
        
        # Пикап
        execute <<-SQL
          UPDATE car_types 
          SET name_uk = 'Пікап', 
              description_uk = 'Легкий вантажівка з відкритою вантажною площадкою ззаду'
          WHERE name = 'Пикап';
        SQL
        
        # Минивэн
        execute <<-SQL
          UPDATE car_types 
          SET name_uk = 'Мінівен', 
              description_uk = 'Мікроавтобус для пасажирських перевезень з двома або трьома рядами сидінь'
          WHERE name = 'Минивэн';
        SQL
        
        # Купе
        execute <<-SQL
          UPDATE car_types 
          SET name_uk = 'Купе', 
              description_uk = 'Двохдверний автомобіль з фіксованою дахом та покатою задньою частиною'
          WHERE name = 'Купе';
        SQL
        
        # Кабриолет
        execute <<-SQL
          UPDATE car_types 
          SET name_uk = 'Кабріолет', 
              description_uk = 'Автомобіль зі складною або знімною дахом'
          WHERE name = 'Кабриолет';
        SQL
        
        # Универсал
        execute <<-SQL
          UPDATE car_types 
          SET name_uk = 'Універсал', 
              description_uk = 'Автомобіль з розширеною вантажною зоною, схожий на хетчбек, але з більшим вантажним простором'
          WHERE name = 'Универсал';
        SQL
        
        # Фургон
        execute <<-SQL
          UPDATE car_types 
          SET name_uk = 'Фургон', 
              description_uk = 'Тип дорожнього транспортного засобу для перевезення товарів або людей'
          WHERE name = 'Фургон';
        SQL
        
        # Легковой автомобиль
        execute <<-SQL
          UPDATE car_types 
          SET name_uk = 'Легковий автомобіль', 
              description_uk = 'Стандартний легковий автомобіль для перевезення пасажирів'
          WHERE name = 'Легковой автомобиль';
        SQL
        
        # Микроавтобус
        execute <<-SQL
          UPDATE car_types 
          SET name_uk = 'Мікроавтобус', 
              description_uk = 'Автобус малої місткості для перевезення до 20 пасажирів'
          WHERE name = 'Микроавтобус';
        SQL
        
        # Легкий коммерческий транспорт
        execute <<-SQL
          UPDATE car_types 
          SET name_uk = 'Легкий комерційний транспорт', 
              description_uk = 'Комерційні автомобілі для перевезення вантажів та пасажирів (Газель, Форд Транзит, Івеко Дейлі)'
          WHERE name = 'Легкий коммерческий транспорт';
        SQL
        
        # Малотоннажный грузовик
        execute <<-SQL
          UPDATE car_types 
          SET name_uk = 'Малотоннажна вантажівка', 
              description_uk = 'Вантажні автомобілі вантажопідйомністю до 3,5 тонн'
          WHERE name = 'Малотоннажный грузовик';
        SQL
      end
    end
  end
end
