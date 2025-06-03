RSpec.configure do |config|
  config.before(:each) do
    # Отключаем автоматическое создание связанных записей в тестах
    User.skip_callback(:create, :after, :create_role_specific_record)
  end
  
  config.after(:each) do
    # Включаем обратно после каждого теста
    User.set_callback(:create, :after, :create_role_specific_record)
  end
end 