require 'rails_helper'

RSpec.describe CarModel, type: :model do
  describe 'associations' do
    it { should belong_to(:brand).class_name('CarBrand').with_foreign_key('brand_id') }
    it { should have_many(:client_cars).with_foreign_key('model_id').dependent(:restrict_with_error) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    
    describe 'name uniqueness within brand' do
      let(:brand) { create(:car_brand) }
      subject { build(:car_model, brand: brand) }
      
      it { should validate_uniqueness_of(:name).scoped_to(:brand_id) }
    end
  end

  describe 'scopes' do
    let(:brand1) { create(:car_brand, name: 'BMW') }
    let(:brand2) { create(:car_brand, name: 'Audi') }
    
    let!(:active_model1) { create(:car_model, brand: brand1, name: 'X5', is_active: true) }
    let!(:active_model2) { create(:car_model, brand: brand2, name: 'A4', is_active: true) }
    let!(:inactive_model) { create(:car_model, brand: brand1, name: 'X3', is_active: false) }

    describe '.active' do
      it 'returns only active car models' do
        expect(CarModel.active).to include(active_model1, active_model2)
        expect(CarModel.active).not_to include(inactive_model)
      end
    end

    describe '.for_brand' do
      it 'returns car models for specified brand' do
        expect(CarModel.for_brand(brand1.id)).to include(active_model1, inactive_model)
        expect(CarModel.for_brand(brand1.id)).not_to include(active_model2)
      end
    end

    describe '.alphabetical' do
      it 'returns car models sorted by name' do
        expect(CarModel.alphabetical.to_a).to eq([active_model2, inactive_model, active_model1])
      end
    end
  end

  describe '#full_name' do
    let(:brand) { create(:car_brand, name: 'BMW') }
    let(:model) { create(:car_model, brand: brand, name: 'X5') }

    it 'returns the full name with brand and model names' do
      expect(model.full_name).to eq('BMW X5')
    end
  end
end
