RSpec.configure do |config|
  config.before(:each) do
    Faker::UniqueGenerator.clear
  end
end 