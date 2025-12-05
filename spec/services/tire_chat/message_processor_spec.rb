# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TireChat::MessageProcessor do
  let(:ai_client) { instance_double(TireChat::AIClient, available?: false) }
  let(:processor) { described_class.new(ai_client: ai_client) }

  describe '#analyze' do
    context 'size detection' do
      it 'detects standard tire size format' do
        result = processor.analyze('Нужны шины 205/55R16')

        expect(result[:type]).to eq('size_request')
        expect(result[:parameters][:size]).to eq('205/55R16')
        expect(result[:confidence]).to be >= 0.9
      end

      it 'detects size with spaces' do
        result = processor.analyze('Размер 225 60 17')

        expect(result[:type]).to eq('size_request')
        expect(result[:parameters][:size]).to eq('225/60R17')
      end

      it 'detects size with "на"' do
        result = processor.analyze('195 65 на 15')

        expect(result[:type]).to eq('size_request')
        expect(result[:parameters][:size]).to eq('195/65R15')
      end

      it 'validates size width range' do
        result = processor.analyze('100/50R10')
        # Too small width should not be detected as size
        expect(result[:type]).not_to eq('size_request')
      end
    end

    context 'season detection' do
      it 'detects winter season in Russian' do
        result = processor.analyze('Нужны зимние шины')

        expect(result[:parameters][:season]).to eq('winter')
        expect(result[:type]).to eq('season_preference')
      end

      it 'detects summer season in Russian' do
        result = processor.analyze('Ищу летние покрышки')

        expect(result[:parameters][:season]).to eq('summer')
      end

      it 'detects all season' do
        result = processor.analyze('Хочу всесезонные')

        expect(result[:parameters][:season]).to eq('all_season')
      end
    end

    context 'price segment detection' do
      it 'detects budget segment' do
        result = processor.analyze('Нужны дешевые шины')

        expect(result[:parameters][:price_segment]).to eq('budget')
        expect(result[:type]).to eq('price_segment_request')
      end

      it 'detects premium segment' do
        result = processor.analyze('Хочу премиум шины')

        expect(result[:parameters][:price_segment]).to eq('premium')
      end

      it 'detects middle segment' do
        result = processor.analyze('Нужны шины среднего сегмента')

        expect(result[:parameters][:price_segment]).to eq('middle')
      end
    end

    context 'complex request detection' do
      it 'detects complex request with multiple intents' do
        result = processor.analyze('Нужны зимние шины 205/55R16')

        expect(result[:type]).to eq('complex_request')
        expect(result[:intent_types]).to include('size_request')
        expect(result[:intent_types]).to include('season_preference')
        expect(result[:parameters][:size]).to eq('205/55R16')
        expect(result[:parameters][:season]).to eq('winter')
      end
    end

    context 'car model detection' do
      it 'detects car brand' do
        result = processor.analyze('Шины для тигуана')

        expect(result[:type]).to eq('complex_request')
        expect(result[:intent_types]).to include('car_model_request')
        expect(result[:parameters][:car_model]).to include('volkswagen')
      end

      it 'detects car with model name' do
        result = processor.analyze('Нужны шины для Toyota Camry')

        expect(result[:type]).to eq('complex_request')
        expect(result[:intent_types]).to include('car_model_request')
      end
    end

    context 'brand comparison detection' do
      it 'detects brand comparison request' do
        result = processor.analyze('Сравни бренды шин')

        expect(result[:type]).to eq('brand_comparison_request')
      end
    end

    context 'size guide detection' do
      it 'detects size guide request' do
        result = processor.analyze('Как выбрать размер шин?')

        expect(result[:type]).to eq('size_guide_request')
      end
    end

    context 'new search detection' do
      it 'detects new search request' do
        result = processor.analyze('Начать новый поиск')

        expect(result[:type]).to eq('new_search_request')
      end

      it 'detects reset request' do
        result = processor.analyze('Сбросить параметры')

        expect(result[:type]).to eq('new_search_request')
      end
    end
  end

  describe '#parse_tire_size' do
    it 'parses standard format' do
      result = processor.parse_tire_size('205/55R16')

      expect(result[:width]).to eq(205)
      expect(result[:height]).to eq(55)
      expect(result[:diameter]).to eq(16)
      expect(result[:full_size]).to eq('205/55R16')
    end

    it 'parses format with spaces' do
      result = processor.parse_tire_size('225 60 17')

      expect(result[:width]).to eq(225)
      expect(result[:height]).to eq(60)
      expect(result[:diameter]).to eq(17)
    end

    it 'returns nil for invalid format' do
      result = processor.parse_tire_size('invalid')
      expect(result).to be_nil
    end
  end

  describe '#normalize_season' do
    it 'normalizes Russian winter' do
      expect(processor.normalize_season('зимние')).to eq('winter')
      expect(processor.normalize_season('зима')).to eq('winter')
    end

    it 'normalizes Russian summer' do
      expect(processor.normalize_season('летние')).to eq('summer')
      expect(processor.normalize_season('лето')).to eq('summer')
    end

    it 'normalizes all season' do
      expect(processor.normalize_season('всесезонные')).to eq('all_season')
    end

    it 'returns original for unknown' do
      expect(processor.normalize_season('unknown')).to eq('unknown')
    end
  end

  describe '#normalize_priority' do
    it 'normalizes price/quality priority' do
      expect(processor.normalize_priority('цена/качество')).to eq('price_quality')
      expect(processor.normalize_priority('соотношение цены')).to eq('price_quality')
    end

    it 'normalizes prestige priority' do
      expect(processor.normalize_priority('престиж')).to eq('prestige')
      expect(processor.normalize_priority('статус')).to eq('prestige')
    end

    it 'normalizes functionality priority' do
      expect(processor.normalize_priority('функциональность')).to eq('functionality')
      expect(processor.normalize_priority('технические характеристики')).to eq('functionality')
    end

    it 'returns balanced for unknown' do
      expect(processor.normalize_priority('unknown')).to eq('balanced')
    end
  end

  describe '#detect_car_brand' do
    it 'detects Volkswagen' do
      result = processor.detect_car_brand('volkswagen tiguan')
      expect(result).to include('volkswagen')
    end

    it 'detects Russian car model names' do
      result = processor.detect_car_brand('тигуан')
      expect(result.any? { |r| r.include?('тигуан') }).to be true
    end

    it 'returns empty array for no match' do
      result = processor.detect_car_brand('hello world')
      expect(result).to eq([])
    end

    it 'does not detect numbers as car models when size pattern present' do
      result = processor.detect_car_brand('peugeot 205/55R16')
      # Should not include '206' or similar from size
      expect(result.any? { |r| r.match?(/\d{3}\//) }).to be false
    end
  end

  describe '#new_search_detected?' do
    it 'returns true for new search patterns' do
      expect(processor.new_search_detected?('шины на тигуан')).to be true
      expect(processor.new_search_detected?('новый поиск')).to be true
      expect(processor.new_search_detected?('начать сначала')).to be true
    end

    it 'returns false for regular messages' do
      expect(processor.new_search_detected?('привет')).to be false
      expect(processor.new_search_detected?('спасибо')).to be false
    end
  end
end
