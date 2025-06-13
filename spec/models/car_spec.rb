require 'rails_helper'

RSpec.describe Car, type: :model do
  describe 'associations' do
    it { should belong_to(:client) }
    it { should belong_to(:car_type) }
    it { should have_many(:bookings).dependent(:restrict_with_error) }
  end

  describe 'validations' do
    let(:client) { create(:client) }
    let(:car_type) { create(:car_type) }
    subject { build(:car, client: client, car_type: car_type) }
    
    it { should validate_presence_of(:brand) }
    it { should validate_presence_of(:model) }
    it { should validate_presence_of(:license_plate) }
    it { should validate_uniqueness_of(:license_plate).case_insensitive }
    it { should validate_numericality_of(:year).only_integer.is_greater_than(1900).is_less_than_or_equal_to(Date.current.year + 1).allow_nil }
    it { should validate_inclusion_of(:is_active).in_array([true, false]).allow_nil }
  end

  describe 'callbacks' do
    let(:client) { create(:client) }
    let(:car_type) { create(:car_type) }
    
    it 'normalizes license plate before save' do
      car = create(:car, client: client, car_type: car_type, license_plate: 'aa 123 bb')
      expect(car.license_plate).to eq('AA123BB')
    end

    it 'sets default is_active value' do
      car = build(:car, client: client, car_type: car_type, is_active: nil)
      car.valid?
      expect(car.is_active).to eq(true)
    end
  end

  describe 'scopes' do
    let(:client) { create(:client) }
    let(:car_type) { create(:car_type) }
    
    let!(:active_car) { create(:car, client: client, car_type: car_type, is_active: true) }
    let!(:inactive_car) { create(:car, client: client, car_type: car_type, is_active: false) }
    let!(:toyota_car) { create(:car, client: client, car_type: car_type, brand: 'Toyota', model: 'Camry') }
    let!(:bmw_car) { create(:car, client: client, car_type: car_type, brand: 'BMW', model: '5 Series', year: 2020) }

    it 'returns active cars' do
      expect(Car.active).to include(active_car)
      expect(Car.active).not_to include(inactive_car)
    end

    it 'returns inactive cars' do
      expect(Car.inactive).to include(inactive_car)
      expect(Car.inactive).not_to include(active_car)
    end

    it 'filters by brand' do
      expect(Car.by_brand('toyota')).to include(toyota_car)
      expect(Car.by_brand('toyota')).not_to include(bmw_car)
    end

    it 'filters by model' do
      expect(Car.by_model('camry')).to include(toyota_car)
      expect(Car.by_model('camry')).not_to include(bmw_car)
    end

    it 'filters by year' do
      expect(Car.by_year(2020)).to include(bmw_car)
      expect(Car.by_year(2020)).not_to include(toyota_car) unless toyota_car.year == 2020
    end

    it 'searches by query' do
      expect(Car.search('toyota')).to include(toyota_car)
      expect(Car.search('bmw')).to include(bmw_car)
      expect(Car.search('camry')).to include(toyota_car)
      expect(Car.search('camry')).not_to include(bmw_car)
    end
  end

  describe 'instance methods' do
    let(:client) { create(:client) }
    let(:car_type) { create(:car_type) }
    let(:car) { build(:car, client: client, car_type: car_type, brand: 'Toyota', model: 'Camry', year: 2020, is_active: false) }

    describe '#full_name' do
      it 'returns formatted car name' do
        expect(car.full_name).to eq('Toyota Camry (2020)')
      end
    end

    describe '#activate!' do
      it 'activates the car' do
        car.save
        car.activate!
        expect(car.reload.is_active).to eq(true)
      end
    end

    describe '#deactivate!' do
      it 'deactivates the car' do
        car.is_active = true
        car.save
        car.deactivate!
        expect(car.reload.is_active).to eq(false)
      end
    end
  end
end
