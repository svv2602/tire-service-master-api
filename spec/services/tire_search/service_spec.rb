# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TireSearch::Service, type: :service do
  describe '#search' do
    context 'with empty query' do
      it 'returns empty response' do
        service = described_class.new('')

        result = service.search

        expect(result[:success]).to be false
        expect(result[:tire_sizes]).to eq([])
      end

      it 'includes suggestions' do
        service = described_class.new('')

        result = service.search

        expect(result[:suggestions]).to be_present
      end
    end

    context 'with tire size query' do
      it 'parses full tire size' do
        service = described_class.new('225/50R17', use_llm: false)

        result = service.search

        expect(result[:success]).to be true
        expect(result[:tire_sizes]).to be_present
      end

      it 'handles partial size (diameter only)' do
        service = described_class.new('R16', use_llm: false)

        result = service.search

        expect(result[:conversation_mode]).to be true
        expect(result[:parsed_data][:diameter]).to eq(16)
      end
    end

    context 'with car query' do
      it 'recognizes BMW brand' do
        service = described_class.new('BMW', use_llm: false)

        result = service.search

        expect(result[:parsed_data][:brand]).to eq('BMW')
      end

      it 'recognizes Cyrillic brand' do
        service = described_class.new('мерседес', use_llm: false)

        result = service.search

        expect(result[:parsed_data][:brand]).to eq('Mercedes')
      end
    end
  end

  describe '#search_by_vehicle' do
    it 'returns vehicle info' do
      service = described_class.new('')

      result = service.search_by_vehicle(brand: 'BMW', model: 'X5')

      expect(result[:vehicle]).to eq({ brand: 'BMW', model: 'X5' })
    end

    it 'includes year when provided' do
      service = described_class.new('')

      result = service.search_by_vehicle(brand: 'BMW', model: 'X5', year: 2020)

      expect(result[:vehicle]).to include(year: 2020)
    end
  end

  describe '#suggest' do
    it 'returns all suggestion types' do
      service = described_class.new('bmw')

      result = service.suggest

      expect(result).to include(:autocomplete, :related, :popular, :spell_correction)
    end

    it 'accepts custom query' do
      service = described_class.new('bmw')

      result = service.suggest('toyota')

      expect(result).to be_present
    end
  end

  describe '#calculate_compatibility' do
    it 'returns compatibility info' do
      service = described_class.new('')
      tire_size = { width: 225, height: 50, diameter: 17 }
      vehicle = { brand: 'BMW', model: 'X5' }

      result = service.calculate_compatibility(tire_size, vehicle)

      expect(result).to include(:compatible, :score)
    end
  end

  describe 'constants' do
    it 'exports BRAND_ALIASES from TireSearchService' do
      expect(described_class::BRAND_ALIASES).to eq(TireSearchService::BRAND_ALIASES)
    end

    it 'exports MODEL_ALIASES from TireSearchService' do
      expect(described_class::MODEL_ALIASES).to eq(TireSearchService::MODEL_ALIASES)
    end

    it 'exports TIRE_BRANDS from TireSearchService' do
      expect(described_class::TIRE_BRANDS).to eq(TireSearchService::TIRE_BRANDS)
    end
  end
end
