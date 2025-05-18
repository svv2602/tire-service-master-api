require 'rails_helper'

RSpec.describe PriceListItem, type: :model do
  describe 'associations' do
    it { should belong_to(:price_list) }
    it { should belong_to(:service) }
  end

  describe 'validations' do
    it { should validate_presence_of(:price) }
    it { should validate_numericality_of(:price).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:discount_price).is_greater_than_or_equal_to(0).allow_nil }
    
    context 'uniqueness validation' do
      subject { create(:price_list_item) }
      it { should validate_uniqueness_of(:service_id).scoped_to(:price_list_id) }
    end

    context 'discount price validation' do
      let(:price_list_item) { build(:price_list_item, price: 100, discount_price: 120) }

      it 'validates that discount price is less than regular price' do
        expect(price_list_item).not_to be_valid
        expect(price_list_item.errors[:discount_price]).to include('must be less than the regular price')
      end
    end
  end

  describe 'delegation' do
    let(:service) { create(:service, name: 'Test Service') }
    let(:price_list_item) { create(:price_list_item, service: service) }

    it 'delegates name to service' do
      expect(price_list_item.service_name).to eq('Test Service')
    end
  end

  describe 'with discount' do
    let(:price_list_item) { create(:price_list_item, :with_discount, price: 100) }

    it 'calculates discount price as 80% of regular price' do
      # Factory trait :with_discount applies 20% discount
      expect(price_list_item.discount_price).to be_within(0.1).of(80)
    end
  end
end
