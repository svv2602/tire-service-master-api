# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TireSearch::QueryBuilder, type: :service do
  describe '#build' do
    subject(:builder) { described_class.new(params) }

    context 'with size filters' do
      let(:params) { { width: 205, height: 55, diameter: 16 } }

      it 'applies width filter' do
        expect(builder.build.to_sql).to include('width')
      end

      it 'applies height filter' do
        expect(builder.build.to_sql).to include('height')
      end

      it 'applies diameter filter' do
        expect(builder.build.to_sql).to include('diameter')
      end
    end

    context 'with invalid size values' do
      let(:params) { { width: 50, height: 10, diameter: 100 } }

      it 'ignores invalid width (out of range)' do
        # Width 50 is outside 125-355 range
        sql = builder.build.to_sql
        expect(sql).not_to include('width = 50')
      end
    end

    context 'with full tire_size hash' do
      let(:params) do
        {
          tire_size: { width: 225, height: 50, diameter: 17 }
        }
      end

      it 'applies full size filter' do
        sql = builder.build.to_sql
        expect(sql).to include('width')
        expect(sql).to include('height')
        expect(sql).to include('diameter')
      end
    end

    context 'with seasonality filter' do
      let(:params) { { seasonality: 'winter' } }

      it 'applies season filter' do
        expect(builder.build.to_sql).to include('season')
      end

      it 'normalizes Russian seasonality' do
        builder_ru = described_class.new(seasonality: 'зимние')
        expect(builder_ru.build.to_sql).to include('season')
      end
    end

    context 'with price filters' do
      let(:params) { { price_min: 1000, price_max: 5000 } }

      it 'applies min price filter' do
        expect(builder.build.to_sql).to include('price_uah >=')
      end

      it 'applies max price filter' do
        expect(builder.build.to_sql).to include('price_uah <=')
      end
    end

    context 'with stock filter' do
      let(:params) { { in_stock: true } }

      it 'applies stock filter' do
        expect(builder.build.to_sql).to include('quantity')
      end
    end

    context 'with sorting' do
      it 'sorts by price ascending' do
        builder = described_class.new(sort: 'price', order: 'asc')
        expect(builder.build.to_sql).to include('price_uah')
      end

      it 'sorts by popularity by default' do
        builder = described_class.new({})
        expect(builder.build.to_sql).to include('popularity_score')
      end
    end
  end

  describe 'constants' do
    it 'defines valid width range' do
      expect(described_class::VALID_WIDTH_RANGE).to eq(125..355)
    end

    it 'defines valid height range' do
      expect(described_class::VALID_HEIGHT_RANGE).to eq(25..85)
    end

    it 'defines valid diameter range' do
      expect(described_class::VALID_DIAMETER_RANGE).to eq(12..24)
    end

    it 'defines sort options' do
      expect(described_class::SORT_OPTIONS).to include('price', 'name', 'popularity')
    end
  end
end
