# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TireSearch::SuggestionEngine, type: :service do
  describe '#autocomplete' do
    it 'returns empty array for short queries' do
      engine = described_class.new('a')

      expect(engine.autocomplete).to eq([])
    end

    it 'returns empty array for blank query' do
      engine = described_class.new('')

      expect(engine.autocomplete).to eq([])
    end

    it 'limits results to MAX_SUGGESTIONS' do
      engine = described_class.new('bmw')

      expect(engine.autocomplete.length).to be <= described_class::MAX_SUGGESTIONS
    end
  end

  describe '#related_searches' do
    it 'returns empty array for blank query' do
      engine = described_class.new('')

      expect(engine.related_searches).to eq([])
    end

    it 'limits results to MAX_RELATED' do
      engine = described_class.new('bmw')

      expect(engine.related_searches.length).to be <= described_class::MAX_RELATED
    end
  end

  describe '#popular_searches' do
    it 'returns POPULAR_QUERIES' do
      engine = described_class.new

      result = engine.popular_searches

      expect(result).to be_an(Array)
      expect(result).not_to be_empty
    end

    it 'respects limit parameter' do
      engine = described_class.new

      result = engine.popular_searches(3)

      expect(result.length).to eq(3)
    end
  end

  describe '#spell_check' do
    it 'returns nil for blank query' do
      engine = described_class.new('')

      expect(engine.spell_check).to be_nil
    end

    it 'returns original query if no correction found' do
      engine = described_class.new('xyznotaword')

      result = engine.spell_check

      expect(result).to eq('xyznotaword')
    end
  end

  describe '#all_suggestions' do
    it 'returns hash with all suggestion types' do
      engine = described_class.new('bmw')

      result = engine.all_suggestions

      expect(result).to include(
        :autocomplete,
        :related,
        :popular,
        :spell_correction
      )
    end
  end

  describe 'constants' do
    it 'defines max suggestions' do
      expect(described_class::MAX_SUGGESTIONS).to eq(10)
    end

    it 'defines max related' do
      expect(described_class::MAX_RELATED).to eq(5)
    end

    it 'defines min query length' do
      expect(described_class::MIN_QUERY_LENGTH).to eq(2)
    end

    it 'contains popular queries' do
      expect(described_class::POPULAR_QUERIES).to include('BMW 3 Series')
      expect(described_class::POPULAR_QUERIES).to include('Toyota Camry')
    end

    it 'contains tire brands' do
      expect(described_class::TIRE_BRANDS).to include('Michelin')
      expect(described_class::TIRE_BRANDS).to include('Continental')
    end
  end
end
