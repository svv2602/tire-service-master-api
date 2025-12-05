# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TireSearch::CompatibilityCalculator, type: :service do
  describe '.normalize_brand' do
    it 'normalizes BMW aliases' do
      expect(described_class.normalize_brand('бмв')).to eq('BMW')
      expect(described_class.normalize_brand('bmw')).to eq('BMW')
    end

    it 'normalizes Mercedes aliases' do
      expect(described_class.normalize_brand('мерседес')).to eq('Mercedes')
      expect(described_class.normalize_brand('mercedes')).to eq('Mercedes')
      expect(described_class.normalize_brand('мерс')).to eq('Mercedes')
    end

    it 'normalizes Volkswagen aliases' do
      expect(described_class.normalize_brand('фольксваген')).to eq('Volkswagen')
      expect(described_class.normalize_brand('vw')).to eq('Volkswagen')
    end

    it 'returns nil for blank input' do
      expect(described_class.normalize_brand('')).to be_nil
      expect(described_class.normalize_brand(nil)).to be_nil
    end

    it 'titleizes unknown brands' do
      expect(described_class.normalize_brand('unknown brand')).to eq('Unknown Brand')
    end
  end

  describe '#initialize' do
    it 'normalizes vehicle data' do
      calculator = described_class.new(brand: 'бмв', model: 'X5', year: 2020)

      expect(calculator.vehicle[:brand]).to eq('BMW')
      expect(calculator.vehicle[:model]).to eq('X5')
      expect(calculator.vehicle[:year]).to eq(2020)
    end

    it 'handles empty vehicle data' do
      calculator = described_class.new({})

      expect(calculator.vehicle).to eq({})
    end
  end

  describe '#find_compatible_sizes' do
    context 'with invalid vehicle' do
      it 'returns empty array when brand is missing' do
        calculator = described_class.new(model: 'Camry')

        expect(calculator.find_compatible_sizes).to eq([])
      end

      it 'returns empty array when model is missing' do
        calculator = described_class.new(brand: 'Toyota')

        expect(calculator.find_compatible_sizes).to eq([])
      end
    end
  end

  describe '#compatible?' do
    let(:calculator) { described_class.new(brand: 'BMW', model: 'X5') }

    it 'returns false for invalid vehicle' do
      empty_calculator = described_class.new({})

      expect(empty_calculator.compatible?({ width: 255, height: 50, diameter: 19 })).to be false
    end
  end

  describe '#calculate_compatibility_score' do
    it 'returns 0 for invalid input' do
      calculator = described_class.new(brand: 'BMW', model: 'X5')

      expect(calculator.calculate_compatibility_score(nil)).to eq(0)
      expect(calculator.calculate_compatibility_score({})).to eq(0)
    end
  end

  describe '#oem_sizes' do
    it 'filters stock sizes only' do
      calculator = described_class.new(brand: 'BMW', model: 'X5')

      oem = calculator.oem_sizes

      expect(oem).to be_an(Array)
      oem.each do |size|
        expect(size[:type]).to eq('stock')
      end
    end
  end

  describe 'constants' do
    it 'defines size types' do
      expect(described_class::SIZE_TYPES).to include(:stock, :optional, :aftermarket)
    end

    it 'defines score weights' do
      expect(described_class::SCORE_WEIGHTS).to include(
        :exact_match,
        :stock_size,
        :optional_size,
        :year_match
      )
    end
  end
end
