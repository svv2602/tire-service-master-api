namespace :db do
  namespace :seed do
    desc "Загрузка минимального набора тестовых данных для разработки"
    task :test_data => :environment do
      puts "Загрузка тестовых данных для разработки..."
      
      # Загружаем пользовательские роли
      load File.join(Rails.root, 'db', 'seeds', 'user_roles.rb')
      
      # Загружаем статусы бронирований
      load File.join(Rails.root, 'db', 'seeds', 'booking_statuses.rb')
      
      # Загружаем типы автомобилей
      load File.join(Rails.root, 'db', 'seeds', 'car_types.rb')
      
      # Запуск нашего исправленного сидера
      load File.join(Rails.root, 'db', 'seeds', 'fix_test_data.rb')
      
      puts "Тестовые данные успешно загружены!"
    end
  end
end
