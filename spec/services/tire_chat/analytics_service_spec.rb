# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TireChat::AnalyticsService do
  describe '.normalize_query' do
    it 'normalizes queries' do
      expect(described_class.normalize_query('Зимние ШИНЫ!')).to eq('зимние шины')
      expect(described_class.normalize_query('  205/55R16  ')).to eq('205 55r16')
    end

    it 'handles nil' do
      expect(described_class.normalize_query(nil)).to be_nil
    end

    it 'handles empty string' do
      expect(described_class.normalize_query('')).to be_nil
    end

    it 'truncates long queries' do
      long_query = 'a' * 500
      result = described_class.normalize_query(long_query)
      expect(result.length).to be <= 255
    end
  end

  describe '.detect_intent' do
    it 'detects winter tire intent' do
      expect(described_class.detect_intent('зимние шины')).to eq('winter_tires')
      expect(described_class.detect_intent('winter tires')).to eq('winter_tires')
      expect(described_class.detect_intent('шины на лед')).to eq('winter_tires')
    end

    it 'detects summer tire intent' do
      expect(described_class.detect_intent('летние шины')).to eq('summer_tires')
      expect(described_class.detect_intent('summer tires')).to eq('summer_tires')
    end

    it 'detects all-season intent' do
      expect(described_class.detect_intent('всесезонные шины')).to eq('all_season_tires')
      expect(described_class.detect_intent('all season tires')).to eq('all_season_tires')
    end

    it 'detects size selection intent' do
      expect(described_class.detect_intent('205/55R16')).to eq('size_selection')
      expect(described_class.detect_intent('какой размер?')).to eq('size_selection')
    end

    it 'detects brand comparison intent' do
      expect(described_class.detect_intent('сравни michelin и continental')).to eq('brand_comparison')
      expect(described_class.detect_intent('что лучше bridgestone или nokian')).to eq('brand_comparison')
    end

    it 'detects price intent' do
      expect(described_class.detect_intent('сколько стоят?')).to eq('price_inquiry')
      expect(described_class.detect_intent('дешевые шины')).to eq('price_inquiry')
      expect(described_class.detect_intent('бюджетные варианты')).to eq('price_inquiry')
    end

    it 'detects recommendation intent' do
      expect(described_class.detect_intent('порекомендуй шины')).to eq('recommendation')
      expect(described_class.detect_intent('посоветуй вариант')).to eq('recommendation')
    end

    it 'detects car-specific intent' do
      expect(described_class.detect_intent('шины для автомобиля')).to eq('car_specific')
      expect(described_class.detect_intent('шины на мою машину')).to eq('car_specific')
    end

    it 'returns general for unknown intent' do
      expect(described_class.detect_intent('hello')).to eq('general')
    end

    it 'handles nil' do
      expect(described_class.detect_intent(nil)).to be_nil
    end
  end

  describe '.track_message' do
    let(:session_id) { 'test_session_123' }
    let(:user_query) { 'зимние шины 205/55R16' }

    it 'creates a chat analytic record' do
      expect do
        described_class.track_message(
          session_id: session_id,
          user_query: user_query
        )
      end.to change(ChatAnalytic, :count).by(1)
    end

    it 'stores all provided data' do
      products = [{ id: 1 }, { id: 2 }]

      analytic = described_class.track_message(
        session_id: session_id,
        user_query: user_query,
        response_type: 'product_recommendation',
        products_shown: products,
        response_time_ms: 150,
        is_quick_question: true,
        is_brand_comparison: false,
        filters_used: { season: 'winter' },
        metadata: { test: true }
      )

      expect(analytic.session_id).to eq(session_id)
      expect(analytic.user_query).to eq(user_query)
      expect(analytic.normalized_query).to eq('зимние шины 205 55r16')
      expect(analytic.response_type).to eq('product_recommendation')
      expect(analytic.products_shown).to eq([1, 2])
      expect(analytic.products_count).to eq(2)
      expect(analytic.had_results).to be true
      expect(analytic.is_quick_question).to be true
      expect(analytic.filters_used).to eq({ 'season' => 'winter' })
    end

    it 'auto-detects intent' do
      analytic = described_class.track_message(
        session_id: session_id,
        user_query: 'зимние шины'
      )

      expect(analytic.intent).to eq('winter_tires')
    end

    it 'uses provided intent over auto-detection' do
      analytic = described_class.track_message(
        session_id: session_id,
        user_query: 'зимние шины',
        intent: 'custom_intent'
      )

      expect(analytic.intent).to eq('custom_intent')
    end

    it 'handles errors gracefully' do
      allow(ChatAnalytic).to receive(:create!).and_raise(StandardError, 'DB error')

      result = described_class.track_message(
        session_id: session_id,
        user_query: user_query
      )

      expect(result).to be_nil
    end
  end

  describe 'analytics methods' do
    before do
      # Create test data
      3.times { create(:chat_analytic, :with_results, normalized_query: 'winter tires', intent: 'winter_tires', created_at: 1.day.ago) }
      2.times { create(:chat_analytic, :without_results, normalized_query: 'rare size', intent: 'size_selection', created_at: 1.day.ago) }
      1.times { create(:chat_analytic, :quick_question, created_at: 1.day.ago) }
    end

    describe '.popular_queries' do
      it 'returns popular queries' do
        result = described_class.popular_queries(limit: 10, days: 7)
        expect(result).to be_an(Array)
        expect(result.first[:count]).to be >= 3
      end
    end

    describe '.no_results_queries' do
      it 'returns queries without results' do
        result = described_class.no_results_queries(limit: 10, days: 7)
        expect(result).to be_an(Array)
        expect(result.any? { |r| r[:query] == 'rare size' }).to be true
      end
    end

    describe '.conversion_rate' do
      it 'returns conversion rate' do
        rate = described_class.conversion_rate(days: 7)
        expect(rate).to be_a(Float)
        expect(rate).to be_between(0, 100)
      end
    end

    describe '.summary' do
      it 'returns summary stats' do
        summary = described_class.summary(days: 7)

        expect(summary).to include(
          :total_queries,
          :queries_with_results,
          :queries_without_results,
          :quick_questions,
          :conversion_rate
        )
      end
    end

    describe '.intent_distribution' do
      it 'returns intent distribution' do
        dist = described_class.intent_distribution(days: 7)

        expect(dist).to be_a(Hash)
        expect(dist['winter_tires']).to be >= 3
      end
    end

    describe '.daily_stats' do
      it 'returns daily breakdown' do
        stats = described_class.daily_stats(days: 7)

        expect(stats).to be_an(Array)
        expect(stats.first).to include(:date, :total, :with_results)
      end
    end
  end
end
