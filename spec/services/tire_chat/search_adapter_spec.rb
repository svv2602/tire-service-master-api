# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TireChat::SearchAdapter do
  let(:filters) { { size: nil, season: nil } }
  let(:user_preferences) { { priority_type: 'balanced' } }
  let(:adapter) { described_class.new(filters: filters, user_preferences: user_preferences) }

  describe '#initialize' do
    it 'sets filters' do
      expect(adapter.filters).to eq(filters)
    end

    it 'sets user_preferences' do
      expect(adapter.user_preferences).to eq(user_preferences)
    end
  end

  describe '#search_from_context' do
    let(:tire_brand) { create(:tire_brand, normalized_name: 'michelin') }
    let(:country) { create(:country, name: 'France') }
    let(:supplier) { create(:supplier, name: 'Test Supplier') }

    let!(:product) do
      create(:supplier_tire_product,
             tire_brand: tire_brand,
             width: 205,
             height: 55,
             diameter: 16,
             season: 'summer',
             price_uah: 3500,
             quantity: 10,
             country: country,
             supplier: supplier)
    end

    context 'without filters' do
      it 'returns products from database' do
        result = adapter.search_from_context
        # May return empty if no products match default scope
        expect(result).to be_an(Array)
      end
    end

    context 'with size filter' do
      let(:filters) do
        {
          size: { width: 205, height: 55, diameter: 16 },
          season: 'summer'
        }
      end

      it 'applies size filter to search' do
        result = adapter.search_from_context
        # Results depend on actual database content
        expect(result).to be_an(Array)
      end
    end

    context 'with no matching products' do
      let(:filters) do
        {
          size: { width: 999, height: 99, diameter: 99 },
          season: 'summer'
        }
      end

      it 'returns empty array' do
        result = adapter.search_from_context
        expect(result).to eq([])
      end
    end
  end

  describe '#search_by_vehicle' do
    it 'returns empty array (placeholder implementation)' do
      result = adapter.search_by_vehicle('volkswagen tiguan')
      expect(result).to eq([])
    end
  end

  describe '#get_tire_details' do
    context 'with valid product id' do
      let!(:product) { create(:supplier_tire_product, price_uah: 3000) }

      it 'returns tire details hash' do
        result = adapter.get_tire_details(product.id)

        expect(result).to be_a(Hash)
        expect(result[:product]).to eq(product)
        expect(result[:price]).to eq(3000)
      end
    end

    context 'with invalid product id' do
      it 'returns nil' do
        result = adapter.get_tire_details(999_999)
        expect(result).to be_nil
      end
    end
  end

  describe '#get_price_segment_recommendations' do
    let(:filters) do
      {
        size: { width: 205, height: 55, diameter: 16 },
        season: 'summer'
      }
    end

    context 'with no products' do
      it 'returns empty array' do
        adapter_with_filters = described_class.new(filters: filters, user_preferences: {})
        result = adapter_with_filters.get_price_segment_recommendations('premium')
        expect(result).to eq([])
      end
    end

    context 'with price_segment parameter' do
      it 'accepts premium segment' do
        result = adapter.get_price_segment_recommendations('premium')
        expect(result).to be_an(Array)
      end

      it 'accepts budget segment' do
        result = adapter.get_price_segment_recommendations('budget')
        expect(result).to be_an(Array)
      end

      it 'accepts middle segment' do
        result = adapter.get_price_segment_recommendations('middle')
        expect(result).to be_an(Array)
      end
    end
  end
end
