# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TireSearchService, type: :service do
  describe '#search' do
    context 'with empty query' do
      it 'returns empty response with error message' do
        service = TireSearchService.new('')

        result = service.search

        expect(result[:success]).to be false
        expect(result[:message]).to include('пуст')
        expect(result[:tire_sizes]).to eq([])
      end

      it 'returns suggestions for empty query' do
        service = TireSearchService.new('')

        result = service.search

        expect(result[:suggestions]).to be_present
      end
    end

    context 'with tire size query' do
      describe 'standard format (225/50R17)' do
        it 'parses tire size correctly' do
          service = TireSearchService.new('225/50R17')

          result = service.search

          expect(result[:tire_sizes]).to be_present
          tire_size = result[:tire_sizes].first
          expect(tire_size[:width]).to eq(225)
          expect(tire_size[:height]).to eq(50)
          expect(tire_size[:diameter]).to eq(17)
        end

        it 'returns success true when size is found' do
          service = TireSearchService.new('225/50R17')

          result = service.search

          expect(result[:success]).to be true
        end
      end

      describe 'alternative formats' do
        it 'parses format with slashes (225/50/17)' do
          service = TireSearchService.new('225/50/17')

          result = service.search

          expect(result[:parsed_data][:tire_size]).to be_present
          expect(result[:parsed_data][:tire_size][:width]).to eq(225)
        end

        it 'parses format with spaces (225 50 17)' do
          service = TireSearchService.new('225 50 17')

          result = service.search

          expect(result[:parsed_data][:tire_size]).to be_present
          expect(result[:parsed_data][:tire_size][:width]).to eq(225)
        end

        it 'parses format with dashes (225-50-17)' do
          service = TireSearchService.new('225-50-17')

          result = service.search

          expect(result[:parsed_data][:tire_size]).to be_present
          expect(result[:parsed_data][:tire_size][:width]).to eq(225)
        end

        it 'parses lowercase r format (225/50r17)' do
          service = TireSearchService.new('225/50r17')

          result = service.search

          expect(result[:parsed_data][:tire_size]).to be_present
        end
      end

      describe 'partial size parsing' do
        it 'parses diameter only (R18)' do
          service = TireSearchService.new('R18', use_llm: false)

          result = service.search

          expect(result[:parsed_data][:diameter]).to eq(18)
          expect(result[:conversation_mode]).to be true
        end

        it 'parses width and height without diameter' do
          service = TireSearchService.new('175 70', use_llm: false)

          result = service.search

          expect(result[:parsed_data][:width]).to eq(175)
          expect(result[:parsed_data][:height]).to eq(70)
          expect(result[:conversation_mode]).to be true
        end

        it 'parses width and diameter (215 на 16)' do
          service = TireSearchService.new('215 на 16', use_llm: false)

          result = service.search

          expect(result[:parsed_data][:width]).to eq(215)
          expect(result[:parsed_data][:diameter]).to eq(16)
        end
      end
    end

    context 'with car brand query' do
      describe 'brand recognition' do
        it 'recognizes BMW brand' do
          service = TireSearchService.new('BMW', use_llm: false)

          result = service.search

          expect(result[:parsed_data][:brand]).to eq('BMW')
        end

        it 'recognizes Cyrillic brand names' do
          service = TireSearchService.new('бмв', use_llm: false)

          result = service.search

          expect(result[:parsed_data][:brand]).to eq('BMW')
        end

        it 'recognizes Volkswagen' do
          service = TireSearchService.new('volkswagen', use_llm: false)

          result = service.search

          expect(result[:parsed_data][:brand]).to eq('Volkswagen')
        end

        it 'recognizes Mercedes aliases' do
          service = TireSearchService.new('мерседес', use_llm: false)

          result = service.search

          expect(result[:parsed_data][:brand]).to eq('Mercedes')
        end

        it 'recognizes Toyota' do
          service = TireSearchService.new('тойота', use_llm: false)

          result = service.search

          expect(result[:parsed_data][:brand]).to eq('Toyota')
        end
      end

      describe 'model recognition' do
        it 'recognizes BMW 3 Series' do
          service = TireSearchService.new('BMW 3 series', use_llm: false)

          result = service.search

          expect(result[:parsed_data][:brand]).to eq('BMW')
          expect(result[:parsed_data][:model]).to eq('3 Series')
        end

        it 'recognizes Volkswagen Tiguan' do
          service = TireSearchService.new('Volkswagen Tiguan', use_llm: false)

          result = service.search

          expect(result[:parsed_data][:brand]).to eq('Volkswagen')
          expect(result[:parsed_data][:model]).to eq('Tiguan')
        end

        it 'recognizes Mercedes E-Class' do
          service = TireSearchService.new('Mercedes E class', use_llm: false)

          result = service.search

          expect(result[:parsed_data][:brand]).to eq('Mercedes')
          expect(result[:parsed_data][:model]).to eq('E-Class')
        end

        it 'recognizes Cyrillic model names' do
          service = TireSearchService.new('фольксваген тигуан', use_llm: false)

          result = service.search

          expect(result[:parsed_data][:brand]).to eq('Volkswagen')
          expect(result[:parsed_data][:model]).to eq('Tiguan')
        end
      end

      describe 'year recognition' do
        it 'recognizes year in query' do
          service = TireSearchService.new('BMW 3 Series 2020', use_llm: false)

          result = service.search

          expect(result[:parsed_data][:year]).to eq(2020)
        end

        it 'ignores invalid years' do
          service = TireSearchService.new('BMW 3 Series 1800', use_llm: false)

          result = service.search

          expect(result[:parsed_data][:year]).to be_nil
        end
      end
    end

    context 'with seasonality' do
      it 'recognizes winter season (зимние)' do
        service = TireSearchService.new('зимние шины', use_llm: false)

        result = service.search

        expect(result[:parsed_data][:seasonality]).to eq('winter')
        expect(result[:seasonality]).to eq('winter')
      end

      it 'recognizes summer season (летние)' do
        service = TireSearchService.new('летние шины', use_llm: false)

        result = service.search

        expect(result[:parsed_data][:seasonality]).to eq('summer')
      end

      it 'recognizes all-season (всесезонные)' do
        service = TireSearchService.new('всесезонные', use_llm: false)

        result = service.search

        expect(result[:parsed_data][:seasonality]).to eq('all_season')
      end

      it 'recognizes Ukrainian seasonality names' do
        service = TireSearchService.new('зимові шини', use_llm: false)

        result = service.search

        expect(result[:parsed_data][:seasonality]).to eq('winter')
      end
    end

    context 'with tire brand query' do
      it 'recognizes Michelin' do
        service = TireSearchService.new('Michelin', use_llm: false)

        result = service.search

        expect(result[:parsed_data][:tire_brands]).to include('Michelin')
      end

      it 'recognizes Cyrillic tire brand names' do
        service = TireSearchService.new('мишлен', use_llm: false)

        result = service.search

        expect(result[:parsed_data][:tire_brands]).to include('Michelin')
      end

      it 'recognizes Continental' do
        service = TireSearchService.new('Continental', use_llm: false)

        result = service.search

        expect(result[:parsed_data][:tire_brands]).to include('Continental')
      end

      it 'recognizes Pirelli' do
        service = TireSearchService.new('pirelli', use_llm: false)

        result = service.search

        expect(result[:parsed_data][:tire_brands]).to include('Pirelli')
      end
    end

    context 'with complex query' do
      it 'parses car brand, model and tire size together' do
        service = TireSearchService.new('BMW X5 225/50R17', use_llm: false)

        result = service.search

        expect(result[:parsed_data][:brand]).to eq('BMW')
        expect(result[:parsed_data][:model]).to eq('X5')
        expect(result[:parsed_data][:tire_size]).to be_present
        expect(result[:parsed_data][:tire_size][:width]).to eq(225)
      end

      it 'parses brand with seasonality and tire brand preference' do
        service = TireSearchService.new('зимние Michelin для BMW', use_llm: false)

        result = service.search

        expect(result[:parsed_data][:seasonality]).to eq('winter')
        expect(result[:parsed_data][:tire_brands]).to include('Michelin')
        expect(result[:parsed_data][:brand]).to eq('BMW')
      end
    end

    context 'conversation mode' do
      it 'enters conversation mode when data is insufficient' do
        service = TireSearchService.new('R16', use_llm: false)

        result = service.search

        expect(result[:conversation_mode]).to be true
        expect(result[:follow_up_questions]).to be_present
      end

      it 'provides context for follow-up' do
        service = TireSearchService.new('R16', use_llm: false)

        result = service.search

        expect(result[:context]).to be_present
        expect(result[:context][:diameter]).to eq(16)
      end
    end

    context 'with context from previous step' do
      it 'merges context with current query' do
        context = { diameter: 16, seasonality: 'winter' }
        service = TireSearchService.new('205 55', use_llm: false, context: context)

        result = service.search

        expect(result[:parsed_data][:diameter]).to eq(16)
        expect(result[:parsed_data][:seasonality]).to eq('winter')
        expect(result[:parsed_data][:width]).to eq(205)
        expect(result[:parsed_data][:height]).to eq(55)
      end

      it 'builds complete tire size from context and query' do
        context = { diameter: 16 }
        service = TireSearchService.new('205 55', use_llm: false, context: context)

        result = service.search

        expect(result[:parsed_data][:tire_size]).to be_present
        expect(result[:parsed_data][:tire_size][:full_size]).to eq('205/55R16')
      end
    end
  end

  describe 'edge cases' do
    it 'handles nil query' do
      service = TireSearchService.new(nil)

      result = service.search

      expect(result[:success]).to be false
    end

    it 'handles whitespace-only query' do
      service = TireSearchService.new('   ')

      result = service.search

      expect(result[:success]).to be false
    end

    it 'does not recognize invalid tire dimensions' do
      service = TireSearchService.new('500/10R30', use_llm: false)

      result = service.search

      # Width 500 and height 10 are outside valid ranges
      expect(result[:parsed_data][:tire_size]).to be_nil
    end
  end

  describe 'BRAND_ALIASES constant' do
    it 'contains common car brands' do
      expected_brands = %w[BMW Volkswagen Mercedes Toyota Honda Audi Ford Hyundai Kia]

      expected_brands.each do |brand|
        expect(TireSearchService::BRAND_ALIASES.values).to include(brand)
      end
    end
  end

  describe 'TIRE_BRANDS constant' do
    it 'contains major tire manufacturers' do
      expected_brands = %w[Michelin Bridgestone Continental Pirelli Goodyear]

      expected_brands.each do |brand|
        expect(TireSearchService::TIRE_BRANDS).to include(brand)
      end
    end
  end

  describe 'SEASONALITY_ALIASES constant' do
    it 'maps to correct season values' do
      expect(TireSearchService::SEASONALITY_ALIASES.values.uniq).to match_array(%w[winter summer all_season])
    end
  end

  describe 'locale support' do
    it 'accepts locale parameter' do
      service = TireSearchService.new('R16', locale: 'uk', use_llm: false)

      result = service.search

      expect(result).to be_present
    end

    it 'generates messages in specified locale' do
      service = TireSearchService.new('R16', locale: 'ru', use_llm: false)

      result = service.search

      # Should not raise error and return valid result
      expect(result[:message]).to be_a(String)
    end
  end

  describe 'LLM integration' do
    context 'when LLM is disabled' do
      it 'does not call OpenAI service' do
        service = TireSearchService.new('BMW X5', use_llm: false)

        expect(OpenaiService).not_to receive(:new)

        service.search
      end
    end

    context 'when LLM is enabled but not available' do
      before do
        allow(OpenaiService).to receive(:available?).and_return(false)
      end

      it 'falls back to simple parsing' do
        service = TireSearchService.new('BMW X5', use_llm: true)

        result = service.search

        expect(result[:parsed_data][:brand]).to eq('BMW')
        expect(result[:parsed_data][:model]).to eq('X5')
      end
    end
  end

  describe 'SearchStats' do
    describe '.record_search' do
      it 'logs search query' do
        expect(Rails.logger).to receive(:info).with(/Search:/)

        TireSearchService::SearchStats.record_search('test query', 5)
      end
    end

    describe '.popular_queries' do
      it 'returns array of popular queries' do
        result = TireSearchService::SearchStats.popular_queries

        expect(result).to be_an(Array)
        expect(result.length).to be <= 10
      end
    end
  end
end
