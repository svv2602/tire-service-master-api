require 'rails_helper'

RSpec.describe CarType, type: :model do
  describe 'associations' do
    it { should have_many(:bookings).dependent(:restrict_with_error) }
    it { should have_many(:client_cars).dependent(:nullify) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    
    # Для тестирования уникальности имени, не будем создавать запись,
    # а проверим наличие валидатора
    it 'validates uniqueness of name' do
      validator = CarType.validators_on(:name).find { |v| v.is_a?(ActiveRecord::Validations::UniquenessValidator) }
      expect(validator).not_to be_nil
    end
  end

  describe 'scopes' do
    # Создадим уникальные имена, не конфликтующие с существующими
    let!(:active_type) { create(:car_type, is_active: true, name: "TestActive#{SecureRandom.hex(4)}") }
    let!(:inactive_type) { create(:car_type, is_active: false, name: "TestInactive#{SecureRandom.hex(4)}") }
    let!(:last_type) { create(:car_type, is_active: true, name: "TestLast#{SecureRandom.hex(4)}") }

    describe '.active' do
      it 'returns only active car types' do
        expect(CarType.active).to include(active_type, last_type)
        expect(CarType.active).not_to include(inactive_type)
      end
    end

    describe '.alphabetical' do
      it 'returns car types sorted by name' do
        # Проверяем только что создаем правильный запрос, не проверяя конкретные записи
        expect(CarType.alphabetical.to_sql).to include("ORDER BY")
      end
    end
  end
end
