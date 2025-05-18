require 'rails_helper'

RSpec.describe PriceList, type: :model do
  describe 'associations' do
    it { should belong_to(:partner) }
    it { should belong_to(:service_point).optional }
    it { should have_many(:price_list_items).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }

    context 'end date validation' do
      let(:price_list) { build(:price_list, start_date: Date.current, end_date: Date.current - 1.day) }

      it 'validates that end date is after start date' do
        expect(price_list).not_to be_valid
        expect(price_list.errors[:end_date]).to include('must be after start date')
      end
    end
  end

  describe 'scopes' do
    let(:partner) { create(:partner) }
    let(:service_point) { create(:service_point, partner: partner) }
    let!(:active_price_list) { create(:price_list, partner: partner, is_active: true) }
    let!(:inactive_price_list) { create(:price_list, partner: partner, is_active: false) }
    let!(:current_price_list) { create(:price_list, partner: partner) }
    let!(:expired_price_list) { create(:price_list, :expired, partner: partner) }
    let!(:future_price_list) { create(:price_list, :future, partner: partner) }
    let!(:global_price_list) { create(:price_list, :global, partner: partner) }
    let!(:service_point_price_list) { create(:price_list, partner: partner, service_point: service_point) }
    let!(:winter_price_list) { create(:price_list, :winter, partner: partner) }
    let!(:summer_price_list) { create(:price_list, :summer, partner: partner) }
    let(:another_partner) { create(:partner) }
    let!(:another_partner_price_list) { create(:price_list, partner: another_partner) }

    describe '.active' do
      it 'returns only active price lists' do
        expect(PriceList.active).to include(active_price_list)
        expect(PriceList.active).not_to include(inactive_price_list)
      end
    end

    describe '.current' do
      it 'returns only current price lists' do
        expect(PriceList.current).to include(current_price_list)
        expect(PriceList.current).not_to include(expired_price_list)
        expect(PriceList.current).not_to include(future_price_list)
      end
    end

    describe '.by_partner' do
      it 'returns price lists for the specified partner' do
        expect(PriceList.by_partner(partner.id)).to include(active_price_list)
        expect(PriceList.by_partner(partner.id)).not_to include(another_partner_price_list)
      end
    end

    describe '.by_service_point' do
      it 'returns price lists for the specified service point' do
        expect(PriceList.by_service_point(service_point.id)).to include(service_point_price_list)
        expect(PriceList.by_service_point(service_point.id)).not_to include(global_price_list)
      end
    end

    describe '.global_for_partner' do
      it 'returns global price lists for the specified partner' do
        expect(PriceList.global_for_partner(partner.id)).to include(global_price_list)
        expect(PriceList.global_for_partner(partner.id)).not_to include(service_point_price_list)
      end
    end

    describe '.winter' do
      it 'returns winter price lists' do
        expect(PriceList.winter).to include(winter_price_list)
        expect(PriceList.winter).not_to include(summer_price_list)
      end
    end

    describe '.summer' do
      it 'returns summer price lists' do
        expect(PriceList.summer).to include(summer_price_list)
        expect(PriceList.summer).not_to include(winter_price_list)
      end
    end
  end

  describe '#global?' do
    context 'when service_point_id is nil' do
      let(:price_list) { create(:price_list, :global) }

      it 'returns true' do
        expect(price_list.global?).to be true
      end
    end

    context 'when service_point_id is present' do
      let(:service_point) { create(:service_point) }
      let(:price_list) { create(:price_list, service_point: service_point) }

      it 'returns false' do
        expect(price_list.global?).to be false
      end
    end
  end
end
