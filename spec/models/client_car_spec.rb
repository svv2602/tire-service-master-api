require 'rails_helper'

RSpec.describe ClientCar, type: :model do
  describe 'associations' do
    it { should belong_to(:client) }
    it { should belong_to(:brand).class_name('CarBrand').with_foreign_key('brand_id') }
    it { should belong_to(:model).class_name('CarModel').with_foreign_key('model_id') }
    it { should belong_to(:tire_type).optional }
    it { should have_many(:bookings).with_foreign_key('car_id').dependent(:nullify) }
  end

  describe 'validations' do
    it { should validate_presence_of(:brand_id) }
    it { should validate_presence_of(:model_id) }
    
    it { should validate_numericality_of(:year).only_integer
                   .is_greater_than(1900)
                   .is_less_than_or_equal_to(Date.current.year + 1)
                   .allow_nil }
                   
    describe 'only_one_primary_per_client validation' do
      let(:client) { create(:client) }
      let(:brand) { create(:car_brand, name: 'BMW') }
      let(:model) { create(:car_model, brand: brand, name: 'X5') }
      let!(:primary_car) { create(:client_car, client: client, brand: brand, model: model, is_primary: true) }
      
      it 'prevents multiple primary cars for the same client' do
        second_car = build(:client_car, client: client, brand: brand, model: model, is_primary: true)
        expect(second_car).not_to be_valid
        expect(second_car.errors[:is_primary]).to include('может быть только один основной автомобиль')
      end
      
      it 'allows non-primary cars for the same client' do
        second_car = build(:client_car, client: client, brand: brand, model: model, is_primary: false)
        expect(second_car).to be_valid
      end
      
      it 'allows primary cars for different clients' do
        other_client = create(:client)
        other_car = build(:client_car, client: other_client, brand: brand, model: model, is_primary: true)
        expect(other_car).to be_valid
      end
    end
  end

  describe 'scopes' do
    let(:client) { create(:client) }
    let(:brand1) { create(:car_brand, name: 'Ford') }
    let(:model1) { create(:car_model, brand: brand1, name: 'Focus') }
    let(:brand2) { create(:car_brand, name: 'Mazda') }
    let(:model2) { create(:car_model, brand: brand2, name: 'CX-5') }
    
    let!(:primary_car) { create(:client_car, client: client, brand: brand1, model: model1, is_primary: true) }
    let!(:regular_car) { create(:client_car, client: client, brand: brand2, model: model2, is_primary: false) }

    describe '.primary' do
      it 'returns only primary cars' do
        expect(ClientCar.primary).to include(primary_car)
        expect(ClientCar.primary).not_to include(regular_car)
      end
    end
  end

  describe '#full_name' do
    let(:brand) { create(:car_brand, name: 'Toyota') }
    let(:model) { create(:car_model, brand: brand, name: 'Camry') }
    
    context 'when year is provided' do
      let(:car) { create(:client_car, brand: brand, model: model, year: 2020) }
      
      it 'returns full name with year' do
        expect(car.full_name).to eq('Toyota Camry (2020)')
      end
    end
    
    context 'when year is not provided' do
      let(:car) { create(:client_car, brand: brand, model: model, year: nil) }
      
      it 'returns full name without year' do
        expect(car.full_name).to eq('Toyota Camry')
      end
    end
  end

  describe '#mark_as_primary!' do
    let(:client) { create(:client) }
    let(:brand1) { create(:car_brand, name: 'Toyota') }
    let(:model1) { create(:car_model, brand: brand1, name: 'Camry') }
    let(:brand2) { create(:car_brand, name: 'Honda') }
    let(:model2) { create(:car_model, brand: brand2, name: 'Civic') }
    
    let!(:existing_primary) { create(:client_car, client: client, brand: brand1, model: model1, is_primary: true) }
    let!(:regular_car) { create(:client_car, client: client, brand: brand2, model: model2, is_primary: false) }
    
    it 'marks the car as primary' do
      regular_car.mark_as_primary!
      expect(regular_car.reload).to be_is_primary
    end
    
    it 'removes primary status from other cars of the same client' do
      regular_car.mark_as_primary!
      expect(existing_primary.reload).not_to be_is_primary
    end
    
    it 'does nothing if the car is already primary' do
      expect {
        existing_primary.mark_as_primary!
      }.not_to change { existing_primary.reload.is_primary }
    end
    
    it 'affects only cars of the same client' do
      other_client = create(:client)
      other_brand = create(:car_brand, name: 'Volvo')
      other_model = create(:car_model, brand: other_brand, name: 'XC90')
      other_primary_car = create(:client_car, client: other_client, brand: other_brand, model: other_model, is_primary: true)
      
      regular_car.mark_as_primary!
      expect(other_primary_car.reload).to be_is_primary
    end
  end
end
