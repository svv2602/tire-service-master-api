# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TireChat::ResponseFormatter do
  let(:formatter) { described_class.new(locale: 'ru') }
  let(:formatter_uk) { described_class.new(locale: 'uk') }

  describe '#initialize' do
    it 'sets default locale to ru' do
      formatter = described_class.new
      expect(formatter.locale).to eq('ru')
    end

    it 'accepts custom locale' do
      expect(formatter_uk.locale).to eq('uk')
    end
  end

  describe '#format_recommendations' do
    context 'with empty recommendations' do
      it 'returns no results message in Russian' do
        result = formatter.format_recommendations([])
        expect(result).to include('К сожалению')
      end

      it 'returns no results message in Ukrainian' do
        result = formatter_uk.format_recommendations([])
        expect(result).to include('На жаль')
      end
    end

    context 'with recommendations' do
      let(:product) do
        double(
          'SupplierTireProduct',
          brand_normalized: 'Michelin',
          original_model: 'Pilot Sport 4',
          width: 205,
          height: 55,
          diameter: 16,
          load_index: '91',
          speed_index: 'V',
          formatted_price: '3500 грн',
          country: double(name: 'France'),
          supplier: double(name: 'Supplier 1')
        )
      end

      let(:recommendations) do
        [
          {
            product: product,
            optimality_score: 9.5,
            recommendation_reasons: ['Высокое качество', 'Популярный выбор'],
            suppliers_count: 2,
            price_savings: 500
          }
        ]
      end

      it 'formats recommendations with all details' do
        result = formatter.format_recommendations(recommendations)

        expect(result).to include('Michelin Pilot Sport 4')
        expect(result).to include('205/55R16')
        expect(result).to include('3500 грн')
        expect(result).to include('9.5/10')
        expect(result).to include('France')
      end

      it 'includes supplier count' do
        result = formatter.format_recommendations(recommendations)
        expect(result).to include('2 поставщиков')
      end

      it 'includes price savings' do
        result = formatter.format_recommendations(recommendations)
        expect(result).to include('500 грн')
      end
    end
  end

  describe '#season_display_name' do
    it 'returns correct Russian names' do
      expect(formatter.season_display_name('winter')).to eq('Зимние')
      expect(formatter.season_display_name('summer')).to eq('Летние')
      expect(formatter.season_display_name('all_season')).to eq('Всесезонные')
    end

    it 'returns correct Ukrainian names' do
      expect(formatter_uk.season_display_name('winter')).to eq('Зимові')
      expect(formatter_uk.season_display_name('summer')).to eq('Літні')
      expect(formatter_uk.season_display_name('all_season')).to eq('Всесезонні')
    end

    it 'capitalizes unknown seasons' do
      expect(formatter.season_display_name('unknown')).to eq('Unknown')
    end
  end

  describe '#price_segment_name' do
    it 'returns correct Russian names' do
      expect(formatter.price_segment_name('premium')).to eq('премиум')
      expect(formatter.price_segment_name('budget')).to eq('бюджетные')
      expect(formatter.price_segment_name('middle')).to eq('средний ценовой сегмент')
    end

    it 'returns correct Ukrainian names' do
      expect(formatter_uk.price_segment_name('premium')).to eq('преміум')
      expect(formatter_uk.price_segment_name('budget')).to eq('бюджетні')
    end
  end

  describe '#format_size_guide' do
    it 'includes size guide title' do
      result = formatter.format_size_guide
      expect(result).to include('Как выбрать правильный размер шин')
    end

    it 'includes popular sizes' do
      result = formatter.format_size_guide
      expect(result).to include('195/65R15')
      expect(result).to include('205/55R16')
    end

    it 'includes call to action' do
      result = formatter.format_size_guide
      expect(result).to include('Введите размер шин')
    end
  end

  describe '#format_brand_comparison' do
    it 'includes brand comparison title' do
      result = formatter.format_brand_comparison
      expect(result).to include('Сравнение брендов шин')
    end

    it 'includes premium brands' do
      result = formatter.format_brand_comparison
      expect(result).to include('Nokian')
      expect(result).to include('Michelin')
      expect(result).to include('Continental')
    end

    it 'includes budget brands' do
      result = formatter.format_brand_comparison
      expect(result).to include('Росава')
      expect(result).to include('Linglong')
    end
  end

  describe '#catalog_button_data' do
    it 'returns nil when size is missing' do
      result = formatter.catalog_button_data(nil, 'winter')
      expect(result).to be_nil
    end

    it 'returns nil when season is missing' do
      size_info = { width: 205, height: 55, diameter: 16 }
      result = formatter.catalog_button_data(size_info, nil)
      expect(result).to be_nil
    end

    it 'returns button data with filters' do
      size_info = { width: 205, height: 55, diameter: 16 }
      result = formatter.catalog_button_data(size_info, 'winter')

      expect(result[:filters]).to eq({
                                       width: 205,
                                       height: 55,
                                       diameter: 16,
                                       season: 'winter'
                                     })
      expect(result[:action]).to eq('apply_catalog_filters')
    end
  end

  describe '#format_continuation_options' do
    it 'includes discussion option' do
      result = formatter.format_continuation_options
      expect(result).to include('Обсудить эти варианты')
    end

    it 'includes new search option' do
      result = formatter.format_continuation_options
      expect(result).to include('Начать новый поиск')
    end
  end
end
