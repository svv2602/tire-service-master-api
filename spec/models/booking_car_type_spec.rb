require 'rails_helper'

RSpec.describe Booking, type: :model do
  describe 'car_type validation' do
    # Тест на наличие валидации car_type_id
    it 'validates presence of car_type_id' do
      # Проверим, что в модели есть валидация присутствия car_type_id
      validators = Booking.validators_on(:car_type_id)
      presence_validator = validators.find { |v| v.is_a?(ActiveRecord::Validations::PresenceValidator) }
      expect(presence_validator).not_to be_nil
    end
  end
  
  describe 'car_type relation' do
    # Проверка наличия ассоциации с car_type
    it 'belongs to car_type' do
      association = Booking.reflect_on_association(:car_type)
      expect(association.macro).to eq(:belongs_to)
    end
    
    # Проверка что ассоциация с car_type обязательна
    it 'requires car_type' do
      association = Booking.reflect_on_association(:car_type)
      expect(association.options[:optional]).to be_falsey
    end
  end
end
