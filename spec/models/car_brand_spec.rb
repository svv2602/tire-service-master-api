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

  describe '#models_count' do
    let(:brand) { create(:car_brand) }

    it 'returns 0 when brand has no models' do
      expect(brand.models_count).to eq(0)
    end

    it 'returns correct count of models' do
      create_list(:car_model, 3, brand: brand)
      expect(brand.models_count).to eq(3)
    end
  end

  describe '#as_json' do
    let(:brand) { create(:car_brand) }

    it 'includes models_count in json representation' do
      create_list(:car_model, 2, brand: brand)
      json = brand.as_json

      expect(json['models_count']).to eq(2)
    end

    context 'when logo is attached' do
      before do
        brand.logo.attach(
          io: File.open(Rails.root.join('spec', 'fixtures', 'files', 'test_logo.png')),
          filename: 'test_logo.png',
          content_type: 'image/png'
        )
      end

      it 'includes logo url in json representation' do
        json = brand.as_json
        expect(json['logo']).to be_present
        expect(json['logo']).to include('/rails/active_storage/blobs/')
      end
    end

    # it 'includes created_at and updated_at in json representation' do
    #   json = brand.as_json(only: [:id, :name, :is_active, :created_at, :updated_at])
    #   expect(json['created_at']).to be_present
    #   expect(json['updated_at']).to be_present
    # end
  end
end
