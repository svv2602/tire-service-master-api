# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TireSearch::ResultProcessor, type: :service do
  let(:scope) { SupplierTireProduct.none }
  let(:options) { { page: 1, per_page: 20 } }

  subject(:processor) { described_class.new(scope, options) }

  describe '#process' do
    it 'returns a hash with expected keys' do
      result = processor.process

      expect(result).to include(:items, :pagination, :facets, :total_count)
    end

    it 'returns empty items for empty scope' do
      result = processor.process

      expect(result[:items]).to eq([])
      expect(result[:total_count]).to eq(0)
    end
  end

  describe 'pagination' do
    it 'calculates correct pagination info' do
      result = processor.process

      expect(result[:pagination]).to include(
        :current_page,
        :per_page,
        :total_pages,
        :total_count,
        :has_next,
        :has_previous
      )
    end

    it 'defaults to page 1' do
      processor = described_class.new(scope, {})
      result = processor.process

      expect(result[:pagination][:current_page]).to eq(1)
    end

    it 'defaults to 20 items per page' do
      processor = described_class.new(scope, {})
      result = processor.process

      expect(result[:pagination][:per_page]).to eq(20)
    end

    it 'enforces maximum page size' do
      processor = described_class.new(scope, { per_page: 500 })
      result = processor.process

      expect(result[:pagination][:per_page]).to eq(100)
    end
  end

  describe 'facets' do
    context 'when facets are not requested' do
      let(:options) { { include_facets: false } }

      it 'returns empty facets hash' do
        result = processor.process

        expect(result[:facets]).to eq({})
      end
    end

    context 'when facets are requested' do
      let(:options) { { include_facets: true } }

      it 'includes all facet types' do
        result = processor.process

        expect(result[:facets]).to include(
          :brands,
          :seasons,
          :widths,
          :heights,
          :diameters,
          :price_range
        )
      end
    end
  end

  describe 'constants' do
    it 'defines default page size' do
      expect(described_class::DEFAULT_PAGE_SIZE).to eq(20)
    end

    it 'defines max page size' do
      expect(described_class::MAX_PAGE_SIZE).to eq(100)
    end
  end
end
