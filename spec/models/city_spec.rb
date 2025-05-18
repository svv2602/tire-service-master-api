require 'rails_helper'

RSpec.describe City, type: :model do
  describe 'associations' do
    it { should belong_to(:region) }
    it { should have_many(:service_points).dependent(:restrict_with_error) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    
    context 'uniqueness validation' do
      subject { create(:city) }
      it { should validate_uniqueness_of(:name).scoped_to(:region_id) }
    end
  end

  describe 'scopes' do
    let!(:active_city) { create(:city, is_active: true) }
    let!(:inactive_city) { create(:city, is_active: false) }

    describe '.active' do
      it 'returns only active cities' do
        expect(City.active).to include(active_city)
        expect(City.active).not_to include(inactive_city)
      end
    end
  end

  describe '#full_name' do
    let(:region) { create(:region, name: 'Moscow Region') }
    let(:city) { create(:city, name: 'Moscow', region: region) }

    it 'returns the full name including region' do
      expect(city.full_name).to eq('Moscow, Moscow Region')
    end
  end
end
