require 'rails_helper'

RSpec.describe CarBrand, type: :model do
  describe 'associations' do
    it { should have_many(:car_models).with_foreign_key('brand_id').dependent(:destroy) }
    it { should have_many(:client_cars).with_foreign_key('brand_id').dependent(:restrict_with_error) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    
    it 'validates uniqueness of name' do
      create(:car_brand, name: 'BMW')
      should validate_uniqueness_of(:name)
    end
  end

  describe 'scopes' do
    let!(:active_brand) { create(:car_brand, is_active: true, name: 'BMW') }
    let!(:inactive_brand) { create(:car_brand, is_active: false, name: 'Audi') }
    let!(:last_brand) { create(:car_brand, is_active: true, name: 'Volvo') }

    describe '.active' do
      it 'returns only active car brands' do
        expect(CarBrand.active).to include(active_brand, last_brand)
        expect(CarBrand.active).not_to include(inactive_brand)
      end
    end

    describe '.alphabetical' do
      it 'returns car brands sorted by name' do
        # Audi is inactive but should still be first alphabetically
        expect(CarBrand.alphabetical.to_a).to eq([inactive_brand, active_brand, last_brand])
      end
    end
  end
end
