require 'rails_helper'

RSpec.describe CarType, type: :model do
  it "can be created" do
    car_type = CarType.new(name: 'Test Type', description: 'Test description')
    expect(car_type.save).to eq(true)
  end
  
  it "requires a name" do
    car_type = CarType.new(description: 'Test description')
    expect(car_type.save).to eq(false)
    expect(car_type.errors[:name]).to include("can't be blank")
  end
end
